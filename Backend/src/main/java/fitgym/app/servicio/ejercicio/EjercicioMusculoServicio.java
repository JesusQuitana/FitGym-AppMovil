package fitgym.app.servicio.ejercicio;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import fitgym.app.model.Ejercicio_Musculo;
import fitgym.app.repositorio.ejercicioRepo.EjercicioMusculoRepositorio;

@Service
public class EjercicioMusculoServicio implements IEjercicioMusculoServicio{

    @Autowired
    private EjercicioMusculoRepositorio ejeRepo;

    @Override
    public List<Ejercicio_Musculo> listarEjercicio_Musculos() {
        return this.ejeRepo.findAll();
    }

    @Override
    public Ejercicio_Musculo buscarEjercicio_MusculoId(Integer id) {
        Ejercicio_Musculo ejeM = this.ejeRepo.findById(id).orElse(null);
        return ejeM;
    }

    @Override
    public Ejercicio_Musculo saveEjercicio_Musculo(Ejercicio_Musculo ejeM) {
        return this.ejeRepo.save(ejeM);
    }

    @Override
    public void deleteId(Integer id) {
        this.ejeRepo.deleteById(id);
    }

}
