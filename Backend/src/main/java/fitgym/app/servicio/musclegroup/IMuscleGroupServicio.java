package fitgym.app.servicio.musclegroup;

import java.util.List;
import fitgym.app.model.MuscleGroup;

public interface IMuscleGroupServicio {
    public List<MuscleGroup> listarMuscleGroup();
    public MuscleGroup buscarMuscleGroupId(Integer id);
    public MuscleGroup saveMuscleGroup(MuscleGroup muscleGroup);
    public void deleteId(Integer id);
}
