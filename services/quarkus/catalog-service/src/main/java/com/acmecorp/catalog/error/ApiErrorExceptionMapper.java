package com.acmecorp.catalog.error;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Provider
public class ApiErrorExceptionMapper implements ExceptionMapper<Throwable> {

    private static final List<String> TRACE_HEADERS = List.of(
            "X-B3-TraceId",
            "X-Request-Id",
            "traceparent"
    );

    @Context
    UriInfo uriInfo;

    @Context
    HttpHeaders headers;

    @Override
    public Response toResponse(Throwable exception) {
        if (exception instanceof ConstraintViolationException validation) {
            Map<String, String> fields = new LinkedHashMap<>();
            validation.getConstraintViolations().stream()
                    .sorted(Comparator.comparing(violation -> violation.getPropertyPath().toString()))
                    .forEach(violation -> fields.putIfAbsent(
                            fieldName(violation),
                            Optional.ofNullable(violation.getMessage()).orElse("Invalid value")
                    ));
            ApiErrorResponse response = buildResponse(
                    Response.Status.BAD_REQUEST.getStatusCode(),
                    "VALIDATION_ERROR",
                    validationMessage(fields),
                    fields
            );
            return Response.status(Response.Status.BAD_REQUEST).type(MediaType.APPLICATION_JSON).entity(response).build();
        }

        if (exception instanceof WebApplicationException webApplicationException) {
            int status = webApplicationException.getResponse().getStatus();
            Response.StatusType statusType = webApplicationException.getResponse().getStatusInfo();
            String message = Optional.ofNullable(webApplicationException.getMessage())
                    .orElse(statusType != null ? statusType.getReasonPhrase() : "Request failed");
            String error = mapStatusToError(status);
            ApiErrorResponse response = buildResponse(status, error, message, null);
            return Response.status(status).type(MediaType.APPLICATION_JSON).entity(response).build();
        }

        ApiErrorResponse response = buildResponse(
                Response.Status.INTERNAL_SERVER_ERROR.getStatusCode(),
                "INTERNAL_ERROR",
                "Internal server error",
                null
        );
        return Response.status(Response.Status.INTERNAL_SERVER_ERROR).type(MediaType.APPLICATION_JSON).entity(response).build();
    }

    private ApiErrorResponse buildResponse(int status, String error, String message, Map<String, String> fields) {
        return new ApiErrorResponse(
                Instant.now(),
                resolveTraceId(),
                status,
                error,
                message,
                resolvePath(),
                fields
        );
    }

    private String resolveTraceId() {
        if (headers == null) {
            return null;
        }
        for (String header : TRACE_HEADERS) {
            String value = headers.getHeaderString(header);
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }

    private String resolvePath() {
        if (uriInfo == null) {
            return null;
        }
        String path = uriInfo.getPath();
        if (path == null) {
            return null;
        }
        return path.startsWith("/") ? path : "/" + path;
    }

    private static String validationMessage(Map<String, String> fields) {
        if (fields.isEmpty()) {
            return "Validation failed";
        }
        Map.Entry<String, String> entry = fields.entrySet().iterator().next();
        return entry.getKey() + ": " + entry.getValue();
    }

    private static String mapStatusToError(int status) {
        if (status == Response.Status.BAD_GATEWAY.getStatusCode()
                || status == Response.Status.SERVICE_UNAVAILABLE.getStatusCode()
                || status == Response.Status.GATEWAY_TIMEOUT.getStatusCode()) {
            return "UPSTREAM_ERROR";
        }
        if (status == Response.Status.NOT_FOUND.getStatusCode()) {
            return "NOT_FOUND";
        }
        if (status == Response.Status.CONFLICT.getStatusCode()) {
            return "CONFLICT";
        }
        if (status >= 400 && status < 500) {
            return "BAD_REQUEST";
        }
        return "INTERNAL_ERROR";
    }

    private static String fieldName(ConstraintViolation<?> violation) {
        String path = violation.getPropertyPath().toString();
        if (path == null || path.isBlank()) {
            return "request";
        }
        int lastDot = path.lastIndexOf('.');
        if (lastDot >= 0 && lastDot + 1 < path.length()) {
            return path.substring(lastDot + 1);
        }
        return path;
    }
}
