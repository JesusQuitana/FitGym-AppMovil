package fitgym.app.servicio.rutina;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import fitgym.app.model.Rutina;
import fitgym.app.repositorio.rutinaRepo.RutinaRepositorio;

@Service
public class RutinaServicio implements IRutinaServicio{

    @Autowired
    private RutinaRepositorio rutinaRepositorio;

    @Override
    public List<Rutina> listarRutina() {
        return this.rutinaRepositorio.findAll();
    }

    @Override
    public Rutina buscarRutinaId(Integer id) {
        Rutina rutina = this.rutinaRepositorio.findById(id).orElse(null);
        return rutina;
    }

    @Override
    public Rutina saveRutina(Rutina rutina) {
        return this.rutinaRepositorio.save(rutina);
    }

    @Override
    public void deleteId(Integer id) {
        this.rutinaRepositorio.deleteById(id);
    }
    
}
