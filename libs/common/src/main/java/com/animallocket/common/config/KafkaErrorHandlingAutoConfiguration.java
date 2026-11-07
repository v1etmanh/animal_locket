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
 */
@AutoConfiguration(after = KafkaAutoConfiguration.class)
@ConditionalOnClass({KafkaTemplate.class, DefaultErrorHandler.class})
public class KafkaErrorHandlingAutoConfiguration {

    public static final String DLQ_SUFFIX = ".dlq";

    @Bean
    @ConditionalOnBean(KafkaTemplate.class)
    @ConditionalOnMissingBean(CommonErrorHandler.class)
    DefaultErrorHandler animalKafkaErrorHandler(KafkaTemplate<Object, Object> template) {
        var recoverer = new DeadLetterPublishingRecoverer(template, KafkaErrorHandlingAutoConfiguration::dlqDestination);
        var handler = new DefaultErrorHandler(recoverer, new FixedBackOff(1000L, 3L));
        handler.addNotRetryableExceptions(IllegalArgumentException.class);
        return handler;
    }

    static TopicPartition dlqDestination(ConsumerRecord<?, ?> record, Exception ex) {
        return new TopicPartition(record.topic() + DLQ_SUFFIX, -1); // -1: để producer chọn partition
    }
}
