package com.animallocket.billing.store;

import com.animallocket.billing.repo.ProductRepository;
import com.google.auth.oauth2.GoogleCredentials;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.io.FileInputStream;
import java.net.http.HttpClient;
import java.time.Clock;
import java.time.Duration;

/**
 * Lắp ráp tích hợp store. Mỗi thành phần chỉ được tạo khi cấu hình đủ; thiếu cấu hình thì bean không tồn tại
 * và {@link StoreRouter} sẽ từ chối (fail closed) thay vì chạy với giá trị mặc định.
 */
@Configuration
@EnableConfigurationProperties({AppleProperties.class, GoogleProperties.class})
public class StoreConfig {
    private static final String APPLE_ROOTS = "!'${animal.billing.apple.root-cert-files:}'.isEmpty()";
    private static final String APPLE_ALL = APPLE_ROOTS
            + " && !'${animal.billing.apple.bundle-id:}'.isEmpty()"
            + " && !'${animal.billing.apple.issuer-id:}'.isEmpty()"
            + " && !'${animal.billing.apple.key-id:}'.isEmpty()"
            + " && !'${animal.billing.apple.private-key-file:}'.isEmpty()";
    private static final String GOOGLE_API = "!'${animal.billing.google.package-name:}'.isEmpty()"
            + " && !'${animal.billing.google.service-account-file:}'.isEmpty()";
    private static final String GOOGLE_PUSH = "!'${animal.billing.google.package-name:}'.isEmpty()"
            + " && !'${animal.billing.google.push-audience:}'.isEmpty()"
            + " && !'${animal.billing.google.push-service-account:}'.isEmpty()";

    @Bean
    @ConditionalOnMissingBean
    Clock storeClock() {
        return Clock.systemUTC();
    }

    @Bean
    @ConditionalOnMissingBean
    StoreCaller storeCaller() {
        return new StoreCaller();
    }

    // ---------------- Apple ----------------

    @Bean
    @ConditionalOnExpression(APPLE_ROOTS)
    AppleJwsVerifier appleJwsVerifier(AppleProperties props, Clock clock) throws Exception {
        return new AppleJwsVerifier(AppleJwsVerifier.loadRoots(props.getRootCertFiles()), props.isRequireAppleOid(), clock);
    }

    @Bean
    @ConditionalOnExpression(APPLE_ALL)
    AppleStoreGateway appleStoreGateway(AppleProperties props, AppleJwsVerifier verifier, StoreCaller caller, Clock clock) {
        return new AppleStoreGateway(props, verifier, restClient(props.getConnectTimeout(), props.getReadTimeout()), caller, clock);
    }

    // ---------------- Google ----------------

    @Bean
    @ConditionalOnExpression(GOOGLE_API)
    GooglePlayClient googlePlayClient(GoogleProperties props, StoreCaller caller) throws Exception {
        GoogleCredentials credentials;
        try (FileInputStream in = new FileInputStream(props.getServiceAccountFile())) {
            credentials = GoogleCredentials.fromStream(in).createScoped("https://www.googleapis.com/auth/androidpublisher");
        }
        HttpGooglePlayClient.AccessTokenProvider tokens = () -> {
            synchronized (credentials) {
                credentials.refreshIfExpired();
                return credentials.getAccessToken().getTokenValue();
            }
        };
        return new HttpGooglePlayClient(props, restClient(props.getConnectTimeout(), props.getReadTimeout()), tokens, caller);
    }

    @Bean
    @ConditionalOnExpression(GOOGLE_API)
    GoogleStoreGateway googleStoreGateway(GoogleProperties props, GooglePlayClient client, ProductRepository products, Clock clock) {
        return new GoogleStoreGateway(props, client, products, clock);
    }

    @Bean
    @ConditionalOnExpression(GOOGLE_PUSH)
    GooglePushAuth googlePushAuth(GoogleProperties props) {
        return OidcGooglePushAuth.create(props);
    }

    private static RestClient restClient(Duration connect, Duration read) {
        HttpClient jdk = HttpClient.newBuilder().connectTimeout(connect).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(jdk);
        factory.setReadTimeout(read);
        return RestClient.builder().requestFactory(factory).build();
    }
}
