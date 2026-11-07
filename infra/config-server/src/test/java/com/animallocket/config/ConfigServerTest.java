package com.animallocket.config;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "eureka.client.enabled=false",
        "spring.security.user.name=config",
        "spring.security.user.password=test-pass"
})
class ConfigServerTest {
    @Autowired TestRestTemplate rest;

    @Test
    void servesSharedConfigFromConfigRepoToAuthenticatedClients() {
        ResponseEntity<String> r = rest.withBasicAuth("config", "test-pass").getForEntity("/user-service/default", String.class);
        assertEquals(HttpStatus.OK, r.getStatusCode());
        assertTrue(r.getBody().contains("eureka.client.service-url.defaultZone"), r.getBody());
        assertTrue(r.getBody().contains("management.endpoints.web.exposure.include"));
    }

    @Test
    void rejectsAnonymousAndWrongCredentials() {
        assertEquals(HttpStatus.UNAUTHORIZED, rest.getForEntity("/user-service/default", String.class).getStatusCode());
        assertEquals(HttpStatus.UNAUTHORIZED,
                rest.withBasicAuth("config", "wrong").getForEntity("/user-service/default", String.class).getStatusCode());
    }

    @Test
    void healthIsPublic() {
        assertEquals(HttpStatus.OK, rest.getForEntity("/actuator/health", String.class).getStatusCode());
    }
}
