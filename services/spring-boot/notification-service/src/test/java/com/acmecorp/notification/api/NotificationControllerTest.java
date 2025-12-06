package com.acmecorp.notification.api;

import com.acmecorp.notification.domain.Notification;
import com.acmecorp.notification.domain.NotificationStatus;
import com.acmecorp.notification.service.NotificationService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(NotificationController.class)
class NotificationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
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
}
