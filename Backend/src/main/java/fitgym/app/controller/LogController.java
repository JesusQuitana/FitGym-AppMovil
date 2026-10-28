package fitgym.app.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/app")
@RequiredArgsConstructor
@CrossOrigin(origins = {"http://localhost:3000"})
public class LogController {

    @PostMapping(value = "demo")
    public String welcome() {
        return "Welcome";
    }
}
