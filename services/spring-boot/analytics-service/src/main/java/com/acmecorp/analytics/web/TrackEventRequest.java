package com.acmecorp.analytics.web;

import javax.validation.constraints.NotBlank;

import java.util.Map;

public class TrackEventRequest {

    @NotBlank
    private String event;

    private Map<String, Object> metadata;

    public TrackEventRequest() {
    }

    public TrackEventRequest(String event, Map<String, Object> metadata) {
        this.event = event;
        this.metadata = metadata;
    }

    public String getEvent() {
        return event;
    }

    public void setEvent(String event) {
        this.event = event;
    }

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata;
    }
}
