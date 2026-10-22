package fitgym.app.model;

import java.time.LocalDate;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import fitgym.app.model.users.User;

@Entity
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Cliente {
    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    Integer id;
    String nombre;
    String apellido;
    String correo;
    String telefono;
    LocalDate fechaPago;
    @ManyToOne
    @JoinColumn(name="membresia_id")
    private Membresia membresia_id;
    @OneToOne
    @JoinColumn(name="user_id")
    private User user_id;


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

    public String getApellido() {
        return this.apellido;
    }

    public void setApellido(String apellido) {
        this.apellido = apellido;
    }

    public String getCorreo() {
        return this.correo;
    }

    public void setCorreo(String correo) {
        this.correo = correo;
    }

    public String getTelefono() {
        return this.telefono;
    }

    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    public LocalDate getFechaPago() {
        return this.fechaPago;
    }

    public void setFechaPago(LocalDate fechaPago) {
        this.fechaPago = fechaPago;
    }

    public Membresia getMembresia_id() {
        return this.membresia_id;
    }

    public void setMembresia_id(Membresia membresia_id) {
        this.membresia_id = membresia_id;
    }

    public User getUser_id() {
        return this.user_id;
    }

    public void setUser_id(User user_id) {
        this.user_id = user_id;
    }

}
