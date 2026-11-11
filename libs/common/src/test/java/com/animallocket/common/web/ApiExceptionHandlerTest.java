package com.animallocket.common.web;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MissingServletRequestParameterException;

import static org.assertj.core.api.Assertions.assertThat;

class ApiExceptionHandlerTest {

    @Test
    void missingRequestParamIsBadRequestNotInternalError() {
        ResponseEntity<ProblemDetail> res = new ApiExceptionHandler()
                .handleMissingParam(new MissingServletRequestParameterException("ids", "List"));

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(res.getBody().getProperties()).containsEntry("code", "VALIDATION_FAILED");
        assertThat(res.getBody().getDetail()).contains("ids");
    }
}
