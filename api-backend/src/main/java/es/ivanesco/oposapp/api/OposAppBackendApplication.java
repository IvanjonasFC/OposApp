package es.ivanesco.oposapp.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class OposAppBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(OposAppBackendApplication.class, args);
	}

}
