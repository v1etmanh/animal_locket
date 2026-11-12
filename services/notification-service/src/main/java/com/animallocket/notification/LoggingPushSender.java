package com.animallocket.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

import java.util.Map;

/** Dùng khi chưa cấu hình FCM (dev): chỉ ghi log, không gửi gì ra ngoài. */
@Component
@ConditionalOnExpression("'${animal.push.fcm.credentials-file:}'.isEmpty()")
public class LoggingPushSender implements PushSender {
    private static final Logger log = LoggerFactory.getLogger(LoggingPushSender.class);

    public LoggingPushSender() {
        log.warn("FCM is not configured: notifications are simulated, no push will be delivered. Set FCM_CREDENTIALS_FILE.");
    }

    @Override
    public Result send(String deviceToken, String title, String body, Map<String, String> data) {
        log.debug("[PUSH giả lập] No notification delivered (FCM not configured)");
        return Result.OK;
    }
}
