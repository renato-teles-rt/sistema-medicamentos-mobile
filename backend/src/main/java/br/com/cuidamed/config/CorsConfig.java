package br.com.cuidamed.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * CORS necessario para o app rodando como web build (`flutter run -d chrome`)
 * chamar a API de outra origem.
 *
 * <p>
 * Em desenvolvimento liberamos qualquer origem porque a porta do Flutter
 * Web muda a cada execucao. Em producao, restrinja via
 * {@code cuidamed.cors.origens-permitidas}.
 * </p>
 */
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    private final String[] origensPermitidas;

    public CorsConfig(
            @org.springframework.beans.factory.annotation.Value("${cuidamed.cors.origens-permitidas:*}") String origens) {
        this.origensPermitidas = origens.split(",");
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns(origensPermitidas)
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .maxAge(3600);
    }
}
