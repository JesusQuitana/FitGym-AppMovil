package fitgym.app.repositorio;

import org.springframework.data.jpa.repository.JpaRepository;

import fitgym.app.model.Cliente;

public interface ClienteRepositorio extends JpaRepository<Cliente, Integer> {

}
