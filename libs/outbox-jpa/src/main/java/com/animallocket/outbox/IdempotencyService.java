package com.animallocket.outbox;

import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

public class IdempotencyService {
    private final ProcessedEventRepository repository;

    public IdempotencyService(ProcessedEventRepository repository) {
        this.repository = repository;
    }

    /**
     * Trả true nếu đây là lần đầu thấy event. Gọi trong cùng transaction với phần xử lý:
     * nếu xử lý lỗi thì dấu vết cũng rollback và event sẽ được xử lý lại.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean firstTime(String eventId) {
        if (repository.existsById(eventId)) {
            return false;
        }
        repository.save(new ProcessedEvent(eventId));
        return true;
    }
}
