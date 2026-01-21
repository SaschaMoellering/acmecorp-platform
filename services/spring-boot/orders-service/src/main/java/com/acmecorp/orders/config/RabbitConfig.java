package com.acmecorp.orders.config;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitConfig {

    public static final String QUEUE_NAME = "notifications-queue";
    public static final String EXCHANGE_NAME = "notifications-exchange";
    public static final String ROUTING_KEY = "notifications.key";

    @Bean
    public Queue notificationsQueue() {
        return new Queue(QUEUE_NAME, true);
    }

    @Bean
    public TopicExchange notificationsExchange() {
        return new TopicExchange(EXCHANGE_NAME);
    }

    @Bean
    public Binding notificationsBinding(Queue notificationsQueue, TopicExchange notificationsExchange) {
        return BindingBuilder.bind(notificationsQueue)
                .to(notificationsExchange)
                .with(ROUTING_KEY);
    }
}
