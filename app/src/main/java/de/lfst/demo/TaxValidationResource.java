package de.lfst.demo;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.json.Json;
import jakarta.json.JsonObject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.time.Instant;
import java.util.regex.Pattern;

@Path("/")
@ApplicationScoped
public class TaxValidationResource {

    private static final Pattern BAVARIAN_TAX_ID_PATTERN = Pattern.compile("^9[0-9]{10}$");

    @GET
    @Path("/info")
    @Produces(MediaType.APPLICATION_JSON)
    public Response getServiceInfo() {
        String tariffYear = System.getenv().getOrDefault("APP_TARIFF_YEAR", "2026");
        String appVersion = System.getenv().getOrDefault("APP_VERSION", "1.0.0");
        String environment = System.getenv().getOrDefault("APP_ENV", "production-rechenzentrum");
        String maintenanceMode = System.getenv().getOrDefault("MAINTENANCE_MODE", "false");

        JsonObject payload = Json.createObjectBuilder()
                .add("service", "steuer-pruefdienst")
                .add("runtime", "WildFly / Jakarta EE 10 (JBoss EAP compatible)")
                .add("version", appVersion)
                .add("tariffYear", tariffYear)
                .add("environment", environment)
                .add("maintenanceMode", Boolean.parseBoolean(maintenanceMode))
                .add("timestamp", Instant.now().toString())
                .build();

        return Response.ok(payload).build();
    }

    @GET
    @Path("/validate")
    @Produces(MediaType.APPLICATION_JSON)
    public Response validateTaxNumber(@QueryParam("steuernummer") String taxNumber) {
        if ("true".equalsIgnoreCase(System.getenv().getOrDefault("MAINTENANCE_MODE", "false"))) {
            JsonObject maintenance = Json.createObjectBuilder()
                    .add("status", "MAINTENANCE")
                    .add("message", "Scheduled maintenance window active")
                    .build();
            return Response.status(Response.Status.SERVICE_UNAVAILABLE).entity(maintenance).build();
        }

        String candidate = (taxNumber == null) ? "" : taxNumber.trim();
        boolean valid = BAVARIAN_TAX_ID_PATTERN.matcher(candidate).matches();

        JsonObject result = Json.createObjectBuilder()
                .add("steuernummer", candidate)
                .add("validFormat", valid)
                .add("jurisdiction", "BY-LfSt")
                .add("tariffYear", System.getenv().getOrDefault("APP_TARIFF_YEAR", "2026"))
                .add("checkedAt", Instant.now().toString())
                .build();

        return Response.ok(result).build();
    }
}
