package br.com.cuidamed.repository;

import br.com.cuidamed.domain.Usuario;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UsuarioRepository extends JpaRepository<Usuario, Long> {

    Optional<Usuario> findByEmail(String email);

    Optional<Usuario> findByGoogleSub(String googleSub);

    Optional<Usuario> findByCodigoVinculo(String codigoVinculo);

    boolean existsByCodigoVinculo(String codigoVinculo);
}
