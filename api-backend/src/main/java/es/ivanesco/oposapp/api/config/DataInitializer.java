package es.ivanesco.oposapp.api.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;

/**
 * Ejecuta migraciones SQL y carga datos iniciales en el arranque.
 * Solo actúa si la tabla convocatorias está vacía.
 * Ficheros en src/main/resources/sql/
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;

    @Override
    public void run(String... args) {
        try {
            // 1) Migraciones estructurales (siempre idempotentes)
            executeSqlResource("sql/migracion_convocatorias.sql");

            // 2) Datos iniciales solo si la tabla está vacía
            Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM tfg.convocatorias", Integer.class);

            if (count != null && count == 0) {
                log.info("⚡ Tabla convocatorias vacía — cargando datos iniciales...");
                executeSqlResource("sql/convocatorias_datos.sql");
                Integer loaded = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM tfg.convocatorias", Integer.class);
                log.info("✅ Cargadas {} convocatorias", loaded);
            } else {
                log.info("✅ Convocatorias ya tiene {} registros — skip", count);
            }
        } catch (Exception e) {
            log.error("❌ Error en DataInitializer: {}", e.getMessage(), e);
        }
    }

    private void executeSqlResource(String path) {
        var populator = new ResourceDatabasePopulator();
        populator.addScript(new ClassPathResource(path));
        populator.setSeparator(";");
        populator.setContinueOnError(true);
        populator.execute(dataSource);
        log.info("✅ Ejecutado SQL: {}", path);
    }
}
