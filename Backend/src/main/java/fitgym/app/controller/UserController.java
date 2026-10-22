package fitgym.app.controller;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;

import fitgym.app.model.users.Role;
import fitgym.app.model.users.User;
import fitgym.app.repositorio.UsuarioRepository;
import fitgym.app.servicio.user.UserRequest;
import fitgym.app.servicio.user.UserService;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PostMapping;




@Controller
@RequestMapping("user")
@CrossOrigin(origins = {"http://localhost:4200"})
@RequiredArgsConstructor
public class UserController {

    //Logger
    private static final Logger logger = LoggerFactory.getLogger(UserController.class);
    
    @Autowired
    UserService userService;
    @Autowired
    UsuarioRepository usuarioRepository;
    
    @GetMapping("/get/{id}")
    public ResponseEntity<User> getUser(@PathVariable Integer id) {
        User user = this.userService.findById(id);

        return ResponseEntity.ok(user);
    }
    
    @PutMapping("update/{id}")
    public ResponseEntity<User> updateUser(@PathVariable Integer id, @RequestBody UserRequest userRequest) {
        User user = this.userService.findById(id);

        if(user!=null) {
            this.userService.updateUser(user);
            return ResponseEntity.ok(user);
        }
        return null;
    }

    @GetMapping("all")
    public ResponseEntity<List<User>> getUsers()
    {   
        List<User> users = userService.findAll();

        logger.info("Usuarios:");
        users.forEach(user->logger.info(user.toString()));

        return ResponseEntity.ok(users);
    }

    @DeleteMapping("delete/{id}")
    public ResponseEntity<User> deleteUser(@PathVariable Integer id) {
        User user = this.userService.findById(id);
        if(user!=null) {
            logger.info("Usuario a Eliminar:");
            logger.info(user.toString());
            this.userService.deleteUser(user);
            return ResponseEntity.ok(user);
        }
        return null;
    }

    @PostMapping("save")
    public ResponseEntity<User> saveUser(@RequestBody User usuario) {
        User user = new User();
        user.setUsername(usuario.getUsername());
        user.setPassword(usuario.getPassword());

        user.setRole(Role.USER);

        this.userService.saveUser(user);
        return ResponseEntity.ok(user);
    }
    
}
