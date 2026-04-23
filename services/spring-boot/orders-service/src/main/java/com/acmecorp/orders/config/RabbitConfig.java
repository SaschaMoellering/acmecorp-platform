package com.acmecorp.orders.config;

import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Declarables;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitConfig {

    public static final String QUEUE_NAME = "notifications-queue";
    public static final String DLQ_NAME = "notifications-queue.dlq";
    public static final String EXCHANGE_NAME = "notifications-exchange";
    public static final String DLX_NAME = "notifications-dlx";
    public static final String ROUTING_KEY = "notifications.key";
    public static final String DLQ_ROUTING_KEY = "notifications.dlq";

    @Bean
    public TopicExchange notificationsExchange() {
        return new TopicExchange(EXCHANGE_NAME);
    }

    @Bean
    public TopicExchange notificationsDeadLetterExchange() {
        return new TopicExchange(DLX_NAME);
    }

    @Bean
    public MessageConverter rabbitMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public Queue notificationsQueue() {
        return QueueBuilder.durable(QUEUE_NAME)
                .deadLetterExchange(DLX_NAME)
                .deadLetterRoutingKey(DLQ_ROUTING_KEY)
                .build();
    }

    @Bean
    public Queue notificationsDeadLetterQueue() {
        return QueueBuilder.durable(DLQ_NAME).build();
    }

    @Bean
    public Declarables notificationTopology(Queue notificationsQueue,
                                            Queue notificationsDeadLetterQueue,
                                            TopicExchange notificationsExchange,
                                            TopicExchange notificationsDeadLetterExchange) {
        return new Declarables(
                notificationsExchange,
                notificationsDeadLetterExchange,
                notificationsQueue,
                notificationsDeadLetterQueue,
                BindingBuilder.bind(notificationsQueue)
                        .to(notificationsExchange)
                        .with(ROUTING_KEY),
                BindingBuilder.bind(notificationsDeadLetterQueue)
                        .to(notificationsDeadLetterExchange)
                        .with(DLQ_ROUTING_KEY)
        );
    }
}
