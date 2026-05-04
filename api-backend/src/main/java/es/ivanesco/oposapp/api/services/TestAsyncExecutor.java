package es.ivanesco.oposapp.api.services;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

/**
 * Bean auxiliar que expone procesarTest() como llamada @Async REAL.
 *
 * ¿Por qué existe este bean?
 * Spring AOP implementa @Async mediante un proxy: solo funciona cuando
 * el método se llama DESDE OTRO BEAN, no desde el mismo objeto (this.xxx()).
 * Si TestController llamara a testService.procesarTest() y ese método
 * viviera en el mismo bean, Spring lo ejecutaría en el hilo actual,
 * bloqueando la respuesta HTTP hasta que Ollama termine (~15 s).
 *
 * Solución: TestController llama a testAsyncExecutor.procesarTest(),
 * que sí pasa por el proxy y se ejecuta en el pool de hilos asíncrono.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class TestAsyncExecutor {

    private final TestService testService;

    @Async
    public void procesarTest(Integer solicitudId) {
        log.debug("[@Async] Iniciando procesamiento solicitudId={} en hilo {}",
                solicitudId, Thread.currentThread().getName());
        testService.procesarTest(solicitudId);
    }
}
