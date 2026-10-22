package fitgym.app.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Data
@AllArgsConstructor 
@NoArgsConstructor 
public class MuscleGroup {

    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    Integer id;
    String musculo;


    public Integer getId() {
        return this.id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getMusculo() {
        return this.musculo;
    }

    public void setMusculo(String musculo) {
        this.musculo = musculo;
    }

}
