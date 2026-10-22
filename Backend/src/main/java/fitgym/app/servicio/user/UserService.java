package fitgym.app.servicio.user;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import fitgym.app.model.users.User;
import fitgym.app.repositorio.UsuarioRepository;

@Service
public class UserService implements IUserService{

    @Autowired
    UsuarioRepository usuarioRepository;

    @Override
    public User findById(Integer id) {
       User user = this.usuarioRepository.findById(id).orElse(null);
       return user;
    }

    @Override
    public void updateUser(User user) {
        this.usuarioRepository.save(user);
    }

    @Override
    public List<User> findAll() {
        List<User> users = this.usuarioRepository.findAll();
        return users;
    }

    @Override
    public void deleteUser(User user) {
        this.usuarioRepository.delete(user);
    }

    @Override
    public void saveUser(User user) {
        this.usuarioRepository.save(user);
    }

}
