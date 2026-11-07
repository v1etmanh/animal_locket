package com.animallocket.user.web;

import com.animallocket.common.Headers;
import com.animallocket.user.dto.Dtos;
import com.animallocket.user.service.AccountService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class UserController {
    private final AccountService accounts;

    public UserController(AccountService accounts) {
        this.accounts = accounts;
    }

    /** Không cần X-Public-Id vì người dùng chưa có hồ sơ; định danh lấy từ sub trong JWT. */
    @PostMapping("/users/register")
    @ResponseStatus(HttpStatus.CREATED)
    public Dtos.MeProfile register(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody Dtos.RegisterRequest req) {
        try {
            return accounts.register(jwt.getSubject(), req);
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            // Hai request đăng ký đồng thời cùng một tài khoản: request thua vi phạm ràng buộc duy nhất của sub.
            // Chạy lại trong transaction mới sẽ thấy hồ sơ do request thắng tạo ra (idempotent), thay vì trả 500.
            return accounts.register(jwt.getSubject(), req);
        }
    }

    @GetMapping("/users/me")
    public Dtos.MeProfile me(@RequestHeader(Headers.PUBLIC_ID) String me) {
        return accounts.me(me);
    }

    @PatchMapping("/users/me")
    public Dtos.MeProfile update(@RequestHeader(Headers.PUBLIC_ID) String me,
                                 @Valid @RequestBody Dtos.UpdateProfileRequest req) {
        return accounts.update(me, req);
    }

    @DeleteMapping("/users/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@RequestHeader(Headers.PUBLIC_ID) String me) {
        accounts.delete(me);
    }

    @GetMapping("/users/{publicId}")
    public Dtos.PublicProfile profile(@RequestHeader(Headers.PUBLIC_ID) String me, @PathVariable String publicId) {
        return accounts.publicProfile(me, publicId);
    }

    @PutMapping("/users/me/lead-animal")
    public Dtos.MeProfile leadAnimal(@RequestHeader(Headers.PUBLIC_ID) String me,
                                     @Valid @RequestBody Dtos.LeadAnimalRequest req) {
        return accounts.setLeadAnimal(me, req.animalCode());
    }

    @GetMapping("/users/me/animals")
    public List<Dtos.AnimalView> myAnimals(@RequestHeader(Headers.PUBLIC_ID) String me) {
        return accounts.myAnimals(me);
    }

    @PostMapping("/users/me/spin")
    public Dtos.SpinResult spin(@RequestHeader(Headers.PUBLIC_ID) String me) {
        return accounts.spin(me);
    }

    @GetMapping("/animals")
    public List<Dtos.AnimalView> catalog() {
        return accounts.catalog();
    }
}
