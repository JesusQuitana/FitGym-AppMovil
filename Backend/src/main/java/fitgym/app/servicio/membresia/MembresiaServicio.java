package fitgym.app.servicio.membresia;

import java.util.List;

import org.springframework.stereotype.Service;

import fitgym.app.model.Membresia;
import fitgym.app.repositorio.MembresiaRepository;

@Service 
public class MembresiaServicio implements IMembresiaServicio{

    private MembresiaRepository membresiaRepository;

    @Override
    public List<Membresia> listarMembresia() {
        return this.membresiaRepository.findAll();
    }

    @Override
    public Membresia buscarMembresiaId(Integer id) {
        Membresia membresia = this.membresiaRepository.findById(id).orElse(null);
        return membresia;
    }

    @Override
    public Membresia saveMembresia(Membresia membresia) {
        return this.membresiaRepository.save(membresia);
    }

    @Override
    public void deleteId(Integer id) {
        this.membresiaRepository.deleteById(id);
    }

}
