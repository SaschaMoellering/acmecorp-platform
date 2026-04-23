package com.acmecorp.notification.config;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class RabbitConfigTest {

    private final RabbitConfig rabbitConfig = new RabbitConfig();

    @Test
    void notificationsQueueShouldDeclareDeadLetterArguments() {
        var queue = rabbitConfig.notificationsQueue();

        assertThat(queue.getName()).isEqualTo(RabbitConfig.QUEUE_NAME);
        assertThat(queue.getArguments())
                .containsEntry("x-dead-letter-exchange", RabbitConfig.DLX_NAME)
                .containsEntry("x-dead-letter-routing-key", RabbitConfig.DLQ_ROUTING_KEY);
    }

    @Test
    void notificationsDeadLetterQueueShouldUseExpectedName() {
        var queue = rabbitConfig.notificationsDeadLetterQueue();

        assertThat(queue.getName()).isEqualTo(RabbitConfig.DLQ_NAME);
    }
}
