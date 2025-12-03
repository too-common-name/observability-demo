package org.example.demo;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpEntity;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@RestController
public class DemoController {

    private final RestTemplate restTemplate;
    private final Logger log = LoggerFactory.getLogger(DemoController.class);
    private final MeterRegistry registry;

    private final String quarkusUrl;
    
    private final Timer palindromeTimer;
    private final Timer analysisTimer;

    public DemoController(MeterRegistry registry, RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
        this.registry = registry;

        this.quarkusUrl = System.getenv("QUARKUS_BACKEND_URL");
        if (this.quarkusUrl == null || this.quarkusUrl.isBlank()) {
            log.error("CRITICAL: QUARKUS_BACKEND_URL environment variable is not set!");
            throw new IllegalStateException("CRITICAL: QUARKUS_BACKEND_URL environment variable is not set!");
        }

        log.info("Backend URL successfully loaded: {}", this.quarkusUrl);

        this.palindromeTimer = registry.timer("springboot_tasks_duration_seconds", "task", "palindrome");
        this.analysisTimer = registry.timer("springboot_tasks_duration_seconds", "task", "analysis");
    }

    @PostMapping(value = "/palindrome", produces = MediaType.TEXT_PLAIN_VALUE)
    public String checkPalindrome(@RequestBody Map<String, String> payload) {
        Timer.Sample sample = Timer.start(registry);

        try {
            String input = payload.getOrDefault("data", "").toLowerCase().replaceAll("[^a-zA-Z0-9]", "");
            log.info("Checking palindrome for: {}", input);

            String reversed = new StringBuilder(input).reverse().toString();
            boolean isPalindrome = input.equals(reversed);

            return isPalindrome ? "Result: '" + input + "' is a palindrome!"
                    : "Result: '" + input + "' is not a palindrome.";

        } finally {
            sample.stop(palindromeTimer);
        }
    }

    @PostMapping(value = "/analyze", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> analyzeSentiment(@RequestBody Map<String, String> payload) {
        Timer.Sample sample = Timer.start(registry);

        try {
            String dataToAnalyze = payload.getOrDefault("data", "empty");
            log.info("Received sentiment request, calling Quarkus backend at {} with data: {}...", quarkusUrl,
                    dataToAnalyze);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<Map<String, String>> request = new HttpEntity<>(payload, headers);

            String response = restTemplate.postForObject(quarkusUrl, request, String.class);

            log.info("Backend analysis successful: {}", response);
            return ResponseEntity.ok(response);

        } catch (ResourceAccessException e) {
            log.error("Backend analysis TIMED OUT: {}", e.getMessage());
            return ResponseEntity.status(504).body("{\"error\":\"Gateway Timeout: Backend service is too slow\"}");

        } catch (HttpServerErrorException | HttpClientErrorException e) {
            log.error("Backend analysis FAILED: {}", e.getMessage());
            return ResponseEntity.status(e.getStatusCode()).body("{\"error\":\"Backend service failed analysis\"}");

        } finally {
            sample.stop(analysisTimer);
        }
    }

    @PostMapping(value = "/stress/{type}")
    public ResponseEntity<String> triggerStress(@PathVariable("type") String type) {
        Timer.Sample sample = Timer.start(registry);
        String targetUrl = quarkusBaseUrl + "/stress/" + type;

        log.warn("TRIGGERING STRESS TEST: {} on backend {}", type, targetUrl);

        try {
            String response = restTemplate.postForObject(targetUrl, null, String.class);
            return ResponseEntity.ok("Stress initiated: " + response);

        } catch (ResourceAccessException e) {
            log.error("Stress request timed out (expected for CPU stress): {}", e.getMessage());
            return ResponseEntity.status(504).body("{\"error\":\"Request timed out, but stress likely started.\"}");
        } catch (Exception e) {
            log.error("Failed to trigger stress: {}", e.getMessage());
            return ResponseEntity.status(500).body("{\"error\":\"Failed to trigger stress\"}");
        } finally {
            sample.stop(stressTimer);
        }
    }

    @PostMapping(value = "/reset")
    public ResponseEntity<String> triggerReset() {
        String targetUrl = quarkusBaseUrl + "/reset";
        try {
            restTemplate.postForObject(targetUrl, null, String.class);
            return ResponseEntity.ok("Backend memory cleared.");
        } catch (Exception e) {
            return ResponseEntity.status(500).body("Reset failed.");
        }
    }
}