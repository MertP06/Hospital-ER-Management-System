package com.acil.er_backend.controller;

import com.acil.er_backend.config.JwtUtil;
import com.acil.er_backend.model.User;
import com.acil.er_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    @PostMapping("/login")
    public ResponseEntity<Map<String, Object>> login(@RequestBody Map<String, String> credentials) {
        String username = credentials.get("username");
        String password = credentials.get("password");

        try {
            Authentication auth = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(username, password));

            String role = auth.getAuthorities().stream()
                    .findFirst()
                    .map(GrantedAuthority::getAuthority)
                    .orElse("ROLE_USER");

            if (role.startsWith("ROLE_")) {
                role = role.substring(5);
            }

            String token = jwtUtil.generateToken(username, role);

            // Update last login
            userRepository.findByUsername(username).ifPresent(user -> {
                user.setLastLoginAt(java.time.LocalDateTime.now());
                userRepository.save(user);
            });

            Map<String, Object> response = new HashMap<>();
            response.put("token", token);
            response.put("username", username);
            response.put("role", role);
            response.put("authenticated", true);

            return ResponseEntity.ok(response);
        } catch (AuthenticationException e) {
            return ResponseEntity.status(401)
                    .body(Map.of("error", "Geçersiz kullanıcı adı veya şifre"));
        }
    }

    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> getCurrentUser(Authentication auth) {
        if (auth == null || !auth.isAuthenticated()) {
            return ResponseEntity.status(401).body(Map.of("error", "Oturum açılmamış"));
        }

        String role = auth.getAuthorities().stream()
                .findFirst()
                .map(GrantedAuthority::getAuthority)
                .orElse("ROLE_USER");

        if (role.startsWith("ROLE_")) {
            role = role.substring(5);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("username", auth.getName());
        response.put("role", role);
        response.put("authenticated", true);

        return ResponseEntity.ok(response);
    }
}
