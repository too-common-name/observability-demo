package org.example;

import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import java.util.Map;
import java.util.Random;

@Path("/")
public class AnalysisResource {

    private static final Logger LOG = LoggerFactory.getLogger(AnalysisResource.class);
    private final MeterRegistry registry;
    private final Random random = new Random();
    private static final java.util.List<byte[]> LEAKY_BUCKET = new java.util.ArrayList<>();

    public AnalysisResource(MeterRegistry registry) {
        this.registry = registry;
    }

    @POST 
    @Path("/analyze")
    public String analyze(Map<String, String> payload) throws Exception {
        String data = payload.getOrDefault("data", "empty");
        LOG.info("Analysis request received for data: {}", data);
        
        registry.counter("quarkus_analysis_requests_total").increment();

        int i = random.nextInt(100);

        if (i < 33) {
            LOG.warn("This analysis will be slow for data: {}", data);
            Thread.sleep(5000);
            registry.counter("quarkus_analysis_total", "status", "slow").increment();
            return "{\"sentiment\":\"NEUTRAL\", \"slow\":true, \"backend\":\"quarkus\"}";

        } else if (i < 66) {
            LOG.error("Analysis failed for data: {}!", data);
            registry.counter("quarkus_analysis_total", "status", "failure").increment();
            throw new RuntimeException("Backend analysis failed!"); 
        
        } else {
            LOG.info("Analysis successful for data: {}", data);
            registry.counter("quarkus_analysis_total", "status", "success").increment();
            return "{\"sentiment\":\"POSITIVE\", \"slow\":false, \"backend\":\"quarkus\"}";
        }
    }

    @POST
    @Path("/stress/{type}")
    public String stress(@jakarta.ws.rs.PathParam("type") String type) {
        if ("memory".equals(type)) {
            LOG.warn("⚠️ Starting MEMORY STRESS test...");
            for (int i = 0; i < 20; i++) {
                LEAKY_BUCKET.add(new byte[10 * 1024 * 1024]);
                LOG.info("Allocated 10MB. Total chunks: " + LEAKY_BUCKET.size());
            }
            return "Allocated 200MB";
        } 
        else if ("cpu".equals(type)) {
            LOG.warn("⚠️ Starting CPU STRESS test...");
            long endTime = System.currentTimeMillis() + 10000;
            while (System.currentTimeMillis() < endTime) {
                Math.pow(Math.random(), Math.random());
            }
            return "Burned CPU for 10s";
        }
        return "Unknown stress type";
    }

    @POST
    @Path("/reset")
    public String reset() {
        LEAKY_BUCKET.clear();
        System.gc();
        return "Memory cleared";
    }
}