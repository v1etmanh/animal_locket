package com.animallocket.common.web;

import com.animallocket.common.Headers;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/** Bảo vệ /internal/**: chỉ service khác trong mạng nội bộ có khoá chung mới gọi được. */
public class InternalTokenFilter extends OncePerRequestFilter {
    private final byte[] expected;

    public InternalTokenFilter(String token) {
        this.expected = token.getBytes(StandardCharsets.UTF_8);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/internal/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String given = req.getHeader(Headers.INTERNAL_TOKEN);
        boolean ok = given != null
                && MessageDigest.isEqual(given.getBytes(StandardCharsets.UTF_8), expected);
        if (!ok) {
            res.setStatus(HttpServletResponse.SC_FORBIDDEN);
            res.setContentType("application/problem+json");
            res.getWriter().write("{\"status\":403,\"code\":\"INTERNAL_ONLY\",\"detail\":\"Chỉ dùng nội bộ\"}");
            return;
        }
        chain.doFilter(req, res);
    }
}
