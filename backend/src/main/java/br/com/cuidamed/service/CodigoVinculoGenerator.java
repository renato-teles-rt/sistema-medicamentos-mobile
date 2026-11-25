package br.com.cuidamed.service;

import br.com.cuidamed.repository.UsuarioRepository;
import java.security.SecureRandom;
import org.springframework.stereotype.Component;

/**
 * Gera o codigo de vinculo de 6 caracteres (A-Z, 0-9), unico no banco.
 *
 * <p>
 * Evita caracteres ambiguos (0/O, 1/I/L) porque o codigo e lido em voz alta
 * ou copiado por WhatsApp entre paciente e cuidador 50+.
 * </p>
 */
@Component
public class CodigoVinculoGenerator {

    private static final char[] ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".toCharArray();
    private static final int TAMANHO = 6;
    private static final int TENTATIVAS_MAXIMAS = 50;

    private final SecureRandom random = new SecureRandom();
    private final UsuarioRepository usuarioRepository;

    public CodigoVinculoGenerator(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    public String gerar() {
        for (int tentativa = 0; tentativa < TENTATIVAS_MAXIMAS; tentativa++) {
            String codigo = sortear();
            if (!usuarioRepository.existsByCodigoVinculo(codigo)) {
                return codigo;
            }
        }
        throw new IllegalStateException("Nao foi possivel gerar um codigo de vinculo unico.");
    }

    private String sortear() {
        StringBuilder sb = new StringBuilder(TAMANHO);
        for (int i = 0; i < TAMANHO; i++) {
            sb.append(ALFABETO[random.nextInt(ALFABETO.length)]);
        }
        return sb.toString();
    }
}
