package fitgym.app.servicio.ejercicio;
import fitgym.app.model.Ejercicios;
import java.util.List;

public interface IEjercicioServicio {
    public List<Ejercicios> listarEjercicios();
    public Ejercicios buscarEjerciciosId(Integer id);
    public Ejercicios saveEjercicios(Ejercicios ejercicio);
    public void deleteId(Integer id);
}
