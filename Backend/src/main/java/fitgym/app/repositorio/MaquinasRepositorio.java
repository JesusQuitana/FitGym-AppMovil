package fitgym.app.repositorio;

import org.springframework.data.jpa.repository.JpaRepository;
import fitgym.app.model.Maquinas;

public interface MaquinasRepositorio extends JpaRepository<Maquinas, Integer> {

}
