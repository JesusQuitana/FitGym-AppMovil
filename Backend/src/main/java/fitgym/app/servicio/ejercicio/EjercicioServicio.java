package fitgym.app.servicio.ejercicio;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import fitgym.app.model.Ejercicios;
import fitgym.app.repositorio.ejercicioRepo.EjercicioRepositorio;

@Service
public class EjercicioServicio implements IEjercicioServicio{

    @Autowired
    private EjercicioRepositorio ejercicioRepositorio;

    @Override
    public List<Ejercicios> listarEjercicios() {
        return this.ejercicioRepositorio.findAll();
    }

    @Override
    public Ejercicios buscarEjerciciosId(Integer id) {
        Ejercicios ejercicio = this.ejercicioRepositorio.findById(id).orElse(null);
        return ejercicio;
    }

    @Override
    public Ejercicios saveEjercicios(Ejercicios ejercicio) {
        return this.ejercicioRepositorio.save(ejercicio);
    }

    @Override
    public void deleteId(Integer id) {
        this.ejercicioRepositorio.deleteById(id);
    }

}
