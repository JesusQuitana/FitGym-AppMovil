package fitgym.app.repositorio;

import org.springframework.data.jpa.repository.JpaRepository;
import fitgym.app.model.users.User;
import java.util.Optional;
import java.util.List;

public interface UsuarioRepository extends JpaRepository<User, Integer> {
    <Optional>User findByUsername(String username);
}
