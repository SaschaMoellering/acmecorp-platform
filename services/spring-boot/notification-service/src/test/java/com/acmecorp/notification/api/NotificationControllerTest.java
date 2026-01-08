package com.acmecorp.notification.api;

import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.service.NotificationService;
import com.acmecorp.notification.web.NotificationRequest;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(NotificationController.class)
class NotificationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private NotificationService notificationService;

    @Test
    void statusEndpointShouldReturnOk() throws Exception {
        mockMvc.perform(get("/api/notification/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("notification-service"));
    }

    @Test
    void listNotificationsShouldReturnPage() throws Exception {
        Notification n = new Notification();
        n.setRecipient("user@example.com");
        n.setMessage("hi");
        n.setStatus(NotificationStatus.QUEUED);
        n.setCreatedAt(Instant.now());
        Mockito.when(notificationService.list(null, null, null, 0, 20))
                .thenReturn(new PageImpl<>(List.of(n)));

        mockMvc.perform(get("/api/notification"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].recipient").value("user@example.com"));
    }

    @Test
    void sendShouldEnqueueNotification() throws Exception {
        Mockito.doNothing().when(notificationService).enqueue(Mockito.any(NotificationRequest.class));

        mockMvc.perform(post("/api/notification/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"recipient\":\"notify@acme.test\",\"message\":\"hello\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("QUEUED"))
                .andExpect(jsonPath("$.recipient").value("notify@acme.test"));

        Mockito.verify(notificationService).enqueue(Mockito.any(NotificationRequest.class));
    }

    @Test
    void getNotificationShouldReturnNotFound() throws Exception {
        Mockito.when(notificationService.get(123L)).thenThrow(new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND, "Notification not found"));

        mockMvc.perform(get("/api/notification/123"))
                .andExpect(status().isNotFound());
    }

    @Test
    void getNotificationShouldReturnResponse() throws Exception {
        Notification notification = new Notification();
        notification.setRecipient("status@acme.test");
        notification.setMessage("hi there");
        notification.setStatus(NotificationStatus.SENT);
        notification.setCreatedAt(Instant.now());
        notification.setSentAt(Instant.now());
        Mockito.when(notificationService.get(5L)).thenReturn(notification);
        Mockito.when(notificationService.toResponse(notification)).thenCallRealMethod();

        mockMvc.perform(get("/api/notification/5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recipient").value("status@acme.test"))
                .andExpect(jsonPath("$.status").value("SENT"));
    }
}
