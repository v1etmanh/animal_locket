package com.animallocket.common.config;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.TopicPartition;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.listener.CommonErrorHandler;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

/**
 * Message xử lý lỗi sau 3 lần thử lại (cách nhau 1 giây) được chuyển sang topic {@code <topic>.dlq} thay vì bị
 * bỏ qua im lặng như mặc định của Spring Kafka. Message không phải event hợp lệ (IllegalArgumentException từ
 * {@code EventJson.read}) vào DLQ ngay, không thử lại vô ích.
 *
 * <p><b>Luồng xử lý một message lỗi</b> (listener ném exception):
 * <pre>
 *   listener ném exception
 *     ├─ là IllegalArgumentException?  ──► KHÔNG thử lại ──► gửi sang "&lt;topic&gt;.dlq"
 *     └─ lỗi khác ──► thử lại sau 1 giây, tối đa 3 lần thử lại (tổng 4 lần xử lý)
 *                      ├─ có lần thành công ──► xong, không vào DLQ
 *                      └─ vẫn lỗi cả 3 lần ──► gửi sang "&lt;topic&gt;.dlq"
 * </pre>
 * Sau khi đã gửi sang DLQ, offset của message gốc được đánh dấu là đã xử lý, nên consumer đi tiếp sang message sau
 * (một message hỏng không chặn cả partition).
 *
 * <p>Service không cần khai báo gì: lớp này được nạp qua {@code AutoConfiguration.imports}. Spring Boot tự gắn
 * bean {@link CommonErrorHandler} (ở đây là {@link DefaultErrorHandler}) vào các {@code @KafkaListener}.
 */
// after = ...: chạy SAU auto-config Kafka của Spring Boot, để lúc kiểm tra @ConditionalOnBean bên dưới
// thì bean KafkaTemplate đã được tạo rồi. Nếu chạy trước, điều kiện luôn sai và handler không bao giờ được tạo.
@AutoConfiguration(after = KafkaAutoConfiguration.class)
// Chỉ bật khi spring-kafka có trên classpath. spring-kafka là dependency "optional" của common, nên service
// nào không khai báo spring-kafka thì lớp này bị bỏ qua hoàn toàn (không lỗi ClassNotFound).
@ConditionalOnClass({KafkaTemplate.class, DefaultErrorHandler.class})
public class KafkaErrorHandlingAutoConfiguration {

    /** Hậu tố tên topic lỗi: message hỏng ở "user.events" được gửi sang "user.events.dlq". */
    public static final String DLQ_SUFFIX = ".dlq";

    // Hai điều kiện của bean:
    //  - @ConditionalOnBean(KafkaTemplate): cần KafkaTemplate để GỬI message sang DLQ; không có thì không tạo.
    //  - @ConditionalOnMissingBean(CommonErrorHandler): nếu service tự định nghĩa error handler riêng thì nhường,
    //    không ghi đè (tránh hai handler cùng tồn tại).
    @Bean
    @ConditionalOnBean(KafkaTemplate.class)
    @ConditionalOnMissingBean(CommonErrorHandler.class)
    DefaultErrorHandler animalKafkaErrorHandler(KafkaTemplate<Object, Object> template) {
        // "Recoverer" = việc làm khi đã hết cách xử lý: ở đây là publish message gốc sang topic DLQ.
        // Hàm dlqDestination quyết định gửi đến topic/partition nào.
        var recoverer = new DeadLetterPublishingRecoverer(template, KafkaErrorHandlingAutoConfiguration::dlqDestination);

        // FixedBackOff(1000L, 3L): chờ cố định 1000 ms giữa các lần, tối đa 3 lần THỬ LẠI.
        // Tính cả lần xử lý đầu tiên thì một message lỗi bị xử lý tối đa 4 lần trước khi vào DLQ.
        // Khi hết lần thử, DefaultErrorHandler gọi recoverer ở trên.
        var handler = new DefaultErrorHandler(recoverer, new FixedBackOff(1000L, 3L));

        // IllegalArgumentException là lỗi "dữ liệu sai", thử lại bao nhiêu lần cũng vẫn sai (ví dụ
        // EventJson.read gặp JSON không hợp lệ, hoặc EventEnvelope.payloadAs không giải mã được payload).
        // Loại này bỏ qua bước thử lại và vào DLQ ngay.
        // Lưu ý: BẤT KỲ IllegalArgumentException nào ném ra từ listener (kể cả từ code nghiệp vụ) cũng bị đối xử
        // như vậy, không chỉ lỗi parse event.
        handler.addNotRetryableExceptions(IllegalArgumentException.class);
        return handler;
    }

    // Hàm chọn đích cho DeadLetterPublishingRecoverer. Nhận message gốc (record) và exception gây lỗi,
    // trả về topic + partition đích. Ở đây chỉ dùng tên topic gốc cộng hậu tố ".dlq"; exception không được dùng.
    static TopicPartition dlqDestination(ConsumerRecord<?, ?> record, Exception ex) {
        // partition = -1: không chỉ định, để producer tự chọn theo khoá message như bình thường.
        // (Nếu chỉ định cứng số partition thì topic DLQ phải có ít nhất bấy nhiêu partition.)
        return new TopicPartition(record.topic() + DLQ_SUFFIX, -1);
    }
}
