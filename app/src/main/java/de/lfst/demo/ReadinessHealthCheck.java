package de.lfst.demo;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Liveness;
import org.eclipse.microprofile.health.Readiness;

@Liveness
@Readiness
@ApplicationScoped
public class ReadinessHealthCheck implements HealthCheck {

    @Override
    public HealthCheckResponse call() {
        boolean maintenance = "true".equalsIgnoreCase(
                System.getenv().getOrDefault("MAINTENANCE_MODE", "false")
        );
        String tariffYear = System.getenv().getOrDefault("APP_TARIFF_YEAR", "2026");

        if (maintenance) {
            return HealthCheckResponse.named("steuer-pruefdienst-readiness")
                    .down()
                    .withData("maintenanceMode", true)
                    .withData("tariffYear", tariffYear)
                    .build();
        }

        return HealthCheckResponse.named("steuer-pruefdienst-readiness")
                .up()
                .withData("maintenanceMode", false)
                .withData("tariffYear", tariffYear)
                .build();
    }
}
