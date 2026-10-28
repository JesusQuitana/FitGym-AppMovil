package fitgym.app.servicio.ejercicio;

import fitgym.app.model.Ejercicio_Musculo;
import java.util.List;

public interface IEjercicioMusculoServicio {
    public List<Ejercicio_Musculo> listarEjercicio_Musculos();
    public Ejercicio_Musculo buscarEjercicio_MusculoId(Integer id);
    public Ejercicio_Musculo saveEjercicio_Musculo(Ejercicio_Musculo ejercicioMusculo);
    public void deleteId(Integer id);
}
