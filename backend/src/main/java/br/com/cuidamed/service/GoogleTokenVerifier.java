package br.com.cuidamed.service;

import br.com.cuidamed.exception.NaoAutorizadoException;
import java.time.Instant;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

/**
 * Valida o ID token do Google chamando o endpoint {@code /tokeninfo} do proprio
 * Google — o mesmo caminho indicado na documentacao oficial de verificacao de
 * ID token e suficiente para este escopo (o token chega assinado pelo Google e
 * o endpoing valida assinatura, emissor e expiracao).
 *
 * <p>
 * <b>Quando {@code cuidamed.google.client-id} esta vazio</b>, o servico
 * entra em modo DEV e aceita tokens sem consultar o Google, apenas logando um
 * aviso. Isso permite rodar o projeto localmente, mas precisa de
 * {@code GOOGLE_CLIENT_ID} definido antes de qualquer deploy.
 * </p>
 */
@Service
public class GoogleTokenVerifier {

    private static final Logger log = LoggerFactory.getLogger(GoogleTokenVerifier.class);

    private final WebClient webClient;
    private final String clientId;

    public GoogleTokenVerifier(
            WebClient.Builder builder,
            @Value("${cuidamed.google.client-id:}") String clientId,
            @Value("${cuidamed.google.token-info-url:https://oauth2.googleapis.com/tokeninfo}") String tokenInfoUrl) {
        this.clientId = clientId == null ? "" : clientId.trim();
        this.webClient = builder.baseUrl(tokenInfoUrl).build();

        if (this.clientId.isEmpty()) {
            log.warn("GOOGLE_CLIENT_ID nao configurado: tokens do Google NAO serao validados. "
                    + "Use apenas em desenvolvimento.");
        }
    }

    /** Dados confiaveis extraidos do token (nunca vem do corpo do app). */
    public record DadosGoogle(String sub, String email, String nome, String fotoUrl) {
    }

    public DadosGoogle verificar(String idToken) {
        if (idToken == null || idToken.isBlank()) {
            throw new NaoAutorizadoException("Token do Google ausente.");
        }

        if (clientId.isEmpty()) {
            return modoDev(idToken);
        }

        Map<String, Object> info;
        try {
            info = webClient.get()
                    .uri(uri -> uri.queryParam("id_token", idToken).build())
                    .retrieve()
                    .bodyToMono(new org.springframework.core.ParameterizedTypeReference<Map<String, Object>>() {
                    })
                    .block();
        } catch (Exception e) {
            log.warn("Falha ao validar ID token junto ao Google: {}", e.getMessage());
            throw new NaoAutorizadoException("Nao foi possivel validar o login do Google. Tente novamente.");
        }

        if (info == null || info.get("email") == null) {
            throw new NaoAutorizadoException("Token do Google invalido ou expirado.");
        }

        // A audiencia precisa ser o nosso client id: impede que um token emitido
        // para outro aplicativo seja aceito aqui.
        Object aud = info.get("aud");
        if (aud == null || !clientId.equals(aud.toString())) {
            throw new NaoAutorizadoException("Token do Google nao pertence a este aplicativo.");
        }

        Object emailVerificado = info.get("email_verified");
        if (emailVerificado != null && !Boolean.parseBoolean(emailVerificado.toString())) {
            throw new NaoAutorizadoException("E-mail do Google nao verificado.");
        }

        verificarExpiracao(info.get("exp"));

        return new DadosGoogle(
                texto(info.get("sub")),
                texto(info.get("email")),
                primeiroNaoVazio(texto(info.get("name")), texto(info.get("email"))),
                texto(info.get("picture")));
    }

    /**
     * Login de desenvolvimento: o proprio token vira a identidade, para que
     * testes de integracao possam criar varios usuarios (paciente, cuidador 1,
     * cuidador 2...) usando tokens diferentes. Sem isso, todos os logins dev
     * caem no mesmo e-mail e o segundo recebe 401 por conflito de perfil.
     */
    private DadosGoogle modoDev(String idToken) {
        String semente = idToken.trim().toLowerCase();
        String email = semente + "@cuidamed.local";
        log.info("Login em modo DEV: token nao validado, usuario {}", email);
        return new DadosGoogle("dev-" + semente, email, "Usuario " + idToken.trim(), null);
    }

    private void verificarExpiracao(Object exp) {
        if (exp == null) {
            return;
        }
        try {
            long expiracao = Long.parseLong(exp.toString());
            if (Instant.now().getEpochSecond() > expiracao) {
                throw new NaoAutorizadoException("Token do Google expirado. Faca login novamente.");
            }
        } catch (NumberFormatException ignored) {
            // Formato inesperado: o proprio /tokeninfo ja rejeitaria, seguimos.
        }
    }

    private static String texto(Object valor) {
        return valor == null ? null : valor.toString();
    }

    private static String primeiroNaoVazio(String a, String b) {
        return a != null && !a.isBlank() ? a : b;
    }
}
