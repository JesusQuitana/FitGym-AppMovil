package fitgym.app.servicio.rutina;
import java.util.List;
import fitgym.app.model.Rutina;

public interface IRutinaServicio {
    public List<Rutina> listarRutina();
    public Rutina buscarRutinaId(Integer id);
    public Rutina saveRutina(Rutina rutina);
    public void deleteId(Integer id);
}
