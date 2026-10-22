package fitgym.app.servicio.maquinas;

import java.util.List;
import fitgym.app.model.Maquinas;

public interface IMaquinasServicio {

    public List<Maquinas> listarMaquinas();
    public Maquinas buscarMaquinaId(Integer id);
    public Maquinas saveMaquina(Maquinas maquina);
    public void deleteId(Integer id);
}
