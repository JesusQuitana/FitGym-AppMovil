package fitgym.app.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Data
@AllArgsConstructor 
@NoArgsConstructor 
public class Maquinas {

    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    Integer id;
    String nombre;
    String descripcion;
    Integer disponibilidad;
    @ManyToOne
    @JoinColumn(name="musculo_id")
    MuscleGroup grupoMuscleGroup;


    public Integer getId() {
        return this.id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getNombre() {
        return this.nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getDescripcion() {
        return this.descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public Integer getDisponibilidad() {
        return this.disponibilidad;
    }

    public void setDisponibilidad(Integer disponibilidad) {
        this.disponibilidad = disponibilidad;
    }

    public MuscleGroup getGrupoMuscleGroup() {
        return this.grupoMuscleGroup;
    }

    public void setGrupoMuscleGroup(MuscleGroup grupoMuscleGroup) {
        this.grupoMuscleGroup = grupoMuscleGroup;
    }

}
