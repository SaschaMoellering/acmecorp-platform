package com.acmecorp.notification.config;

import org.springframework.amqp.core.AcknowledgeMode;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Declarables;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.rabbit.config.RetryInterceptorBuilder;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.retry.RejectAndDontRequeueRecoverer;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.amqp.rabbit.config.RetryInterceptorBuilder.StatelessRetryInterceptorBuilder;
import org.springframework.boot.amqp.autoconfigure.SimpleRabbitListenerContainerFactoryConfigurer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.aopalliance.intercept.MethodInterceptor;

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
        return new JacksonJsonMessageConverter();
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
        Binding notificationsBinding = BindingBuilder.bind(notificationsQueue)
                .to(notificationsExchange)
                .with(ROUTING_KEY);
        Binding notificationsDeadLetterBinding = BindingBuilder.bind(notificationsDeadLetterQueue)
                .to(notificationsDeadLetterExchange)
                .with(DLQ_ROUTING_KEY);
        return new Declarables(
                notificationsExchange,
                notificationsDeadLetterExchange,
                notificationsQueue,
                notificationsDeadLetterQueue,
                notificationsBinding,
                notificationsDeadLetterBinding
        );
    }

    @Bean
    public MethodInterceptor notificationRetryInterceptor(
            @Value("${acmecorp.messaging.notification.retry.max-attempts:3}") int maxAttempts,
            @Value("${acmecorp.messaging.notification.retry.initial-interval:1000}") long initialInterval,
            @Value("${acmecorp.messaging.notification.retry.multiplier:2.0}") double multiplier,
            @Value("${acmecorp.messaging.notification.retry.max-interval:5000}") long maxInterval) {
        StatelessRetryInterceptorBuilder builder = RetryInterceptorBuilder.stateless()
                .maxRetries(maxAttempts)
                .backOffOptions(initialInterval, multiplier, maxInterval);
        return builder.recoverer(new RejectAndDontRequeueRecoverer()).build();
    }

    @Bean
    public SimpleRabbitListenerContainerFactory notificationListenerContainerFactory(
            SimpleRabbitListenerContainerFactoryConfigurer configurer,
            ConnectionFactory connectionFactory,
            MethodInterceptor notificationRetryInterceptor) {
        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        configurer.configure(factory, connectionFactory);
        factory.setAdviceChain(notificationRetryInterceptor);
        factory.setDefaultRequeueRejected(false);
        factory.setAcknowledgeMode(AcknowledgeMode.AUTO);
        return factory;
    }
}
