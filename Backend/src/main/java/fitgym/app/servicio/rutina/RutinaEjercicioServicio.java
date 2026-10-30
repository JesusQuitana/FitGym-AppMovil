package fitgym.app.servicio.rutina;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import fitgym.app.model.Rutina_Ejercicio;
import fitgym.app.repositorio.rutinaRepo.RutinaEjercicioRepositorio;

@Service
public class RutinaEjercicioServicio implements IRutinaEjercicioServicio{

    @Autowired
    private RutinaEjercicioRepositorio reRepo;

    @Override
    public List<Rutina_Ejercicio> listarRutina_Ejercicios() {
        return this.reRepo.findAll();
    }

    @Override
    public Rutina_Ejercicio buscarRutina_EjercicioId(Integer id) {
        Rutina_Ejercicio re = this.reRepo.findById(id).orElse(null);
        return re;
    }

    @Override
    public Rutina_Ejercicio saveRutina_Ejercicio(Rutina_Ejercicio re) {
        return this.reRepo.save(re);
    }

    @Override
    public void deleteId(Integer id) {
        this.reRepo.deleteById(id);
    }

}
