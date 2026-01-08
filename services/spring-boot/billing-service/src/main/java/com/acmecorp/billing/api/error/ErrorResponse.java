package com.acmecorp.billing.api.error;

import java.util.Map;

public record ErrorResponse(String code, String message, Map<String, Object> details) {
}
