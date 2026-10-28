package fitgym.app.servicio.rutina;

import java.util.List;
import fitgym.app.model.Rutina_Ejercicio;

public interface IRutinaEjercicioServicio {
    public List<Rutina_Ejercicio> listarRutina_Ejercicios();
    public Rutina_Ejercicio buscarRutina_EjercicioId(Integer id);
    public Rutina_Ejercicio saveRutina_Ejercicio(Rutina_Ejercicio rutinaEjercicio);
    public void deleteId(Integer id);
}
