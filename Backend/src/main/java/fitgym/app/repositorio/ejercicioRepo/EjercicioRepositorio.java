package fitgym.app.repositorio.ejercicioRepo;
import org.springframework.data.jpa.repository.JpaRepository;
import fitgym.app.model.Ejercicios;

public interface EjercicioRepositorio extends JpaRepository<Ejercicios, Integer>{
    
}
