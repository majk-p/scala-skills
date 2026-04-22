# Play Framework — Basics Reference

Deeper patterns for controllers, routing, JSON, forms, and database integration.
Complements the main `SKILL.md` which covers the essentials.

## Action Types

### Composition and Chaining

```scala
import play.api.mvc._
import scala.concurrent.{ExecutionContext, Future}

// Async action returning Future[Result]
def asyncAction: Action[AnyContent] = Action.async { implicit request =>
  Future {
    Ok("async result")
  }
}

// Action with custom body parser
def jsonAction: Action[JsValue] = Action(parse.json) { implicit request =>
  Ok(request.body)
}

// Action with tolerant JSON parser (accepts non-JSON too)
def tolerantAction: Action[AnyContent] = Action(parse.tolerantJson) { implicit request =>
  Ok("received")
}

// Composing actions with ActionBuilder
def secureAction: Action[AnyContent] = Action.async { implicit request =>
  request.headers.get("Authorization") match {
    case Some(token) if validateToken(token) =>
      Future.successful(Ok("authorized"))
    case _ =>
      Future.successful(Unauthorized("missing or invalid token"))
  }
}

private def validateToken(token: String): Boolean = token.nonEmpty
```

### Action Builders for Cross-Cutting Concerns

```scala
import javax.inject._
import play.api.mvc._
import scala.concurrent.{ExecutionContext, Future}

class AuthenticatedActionBuilder @Inject()(
  parser: BodyParsers.Default
)(implicit ec: ExecutionContext) extends ActionBuilder[Request, AnyContent] {

  override def parser: BodyParser[AnyContent] = parser
  override def invokeBlock[A](request: Request[A], block: Request[A] => Future[Result]): Future[Result] = {
    request.headers.get("X-Auth-Token") match {
      case Some(token) if isValid(token) => block(request)
      case _ => Future.successful(Unauthorized("Authentication required"))
    }
  }

  private def isValid(token: String): Boolean = token.length > 10
}
```

## Request Body Parsers

```scala
import play.api.mvc._
import play.api.libs.json._
import scala.concurrent.ExecutionContext

class UploadController @Inject()(val controllerComponents: ControllerComponents)
(implicit ec: ExecutionContext) extends BaseController {

  // File upload parser
  def upload = Action(parse.file(to = new java.io.File("/tmp/upload.dat"))) { request =>
    Ok(s"Uploaded file of size: ${request.body.length()}")
  }

  // Max length body parser (e.g., 10KB limit)
  def limitedJson: Action[JsValue] = Action(parse.json(maxLength = 10240)) { request =>
    Ok(request.body)
  }

  // Raw body (for streaming)
  def raw: Action[AnyContent] = Action(parse.raw) { request =>
    Ok(s"Raw body size: ${request.body.size}")
  }

  // Form URL-encoded
  def formPost: Action[AnyContent] = Action(parse.formUrlEncoded) { implicit request =>
    val name = request.body.get("name").flatMap(_.headOption).getOrElse("unknown")
    Ok(s"Hello $name")
  }
}
```

## Routing Details

### Route Parameters and Constraints

```
# conf/routes

# Static path
GET     /health                 controllers.HealthController.check

# Single parameter
GET     /users/:id              controllers.UserController.getById(id: Long)

# Wildcard (matches /, captures rest)
GET     /files/*file            controllers.FileController.serve(file: String)

# Query parameters handled in controller, not in routes
GET     /search                 controllers.SearchController.search(q: String, page: Int ?= 1)
```

### Reverse Routing

```scala
// Generate URLs from route definitions
import routes.javascript._

// In a template or controller
val userUrl: String = routes.UserController.getById(42L).url
// => "/users/42"

val absoluteUrl: String = routes.UserController.getById(42L).absoluteURL(request)
// => "http://example.com/users/42"
```

### Programmatic Routing with Sird

```scala
import play.api.routing.sird._
import play.api.routing.SimpleRouter
import play.api.mvc._

class ApiRouter(controller: ApiController) extends SimpleRouter {
  val prefix = "/api/v2"

  def routes = {
    case GET(p"/users")           => controller.listUsers
    case GET(p"/users/$id")       => controller.getUser(id.toLong)
    case POST(p"/users")          => controller.createUser
    case PUT(p"/users/$id")       => controller.updateUser(id.toLong)
    case DELETE(p"/users/$id")    => controller.deleteUser(id.toLong)
    case GET(p"/search" ? q"query=$q" & s"page=$page") =>
      controller.search(q, page.toInt)
  }
}
```

## JSON — Manual Reads/Writes

```scala
import play.api.libs.json._
import play.api.libs.functional.syntax._

case class Address(street: String, city: String, zip: String)
case class Person(name: String, age: Int, address: Address)

// Manual Writes using combinators
implicit val addressWrites: Writes[Address] = (
  (__ \ "street").write[String] and
  (__ \ "city").write[String] and
  (__ \ "zip").write[String]
)(unlift(Address.unapply))

implicit val personWrites: Writes[Person] = (
  (__ \ "name").write[String] and
  (__ \ "age").write[Int] and
  (__ \ "address").write[Address]
)(unlift(Person.unapply))

// Manual Reads with validation
implicit val addressReads: Reads[Address] = (
  (__ \ "street").read[String](minLength[String](1)) and
  (__ \ "city").read[String](minLength[String](1)) and
  (__ \ "zip").read[String](pattern("[0-9]{5}".r))
)(Address.apply _)

implicit val personReads: Reads[Person] = (
  (__ \ "name").read[String](minLength[String](1)) and
  (__ \ "age").read[Int](min(0) keepAnd max(150)) and
  (__ \ "address").read[Address]
)(Person.apply _)

// Using in controller
def createPerson: Action[JsValue] = Action(parse.json) { request =>
  request.body.validate[Person].fold(
    errors => BadRequest(Json.obj("errors" -> errors.map { case (path, errs) =>
      Json.obj("path" -> path.toString, "messages" -> errs.map(_.message))
    })),
    person => Created(Json.toJson(person))
  )
}
```

## Form Handling and Validation

```scala
import javax.inject._
import play.api.mvc._
import play.api.data._
import play.api.data.Forms._
import play.api.data.validation.Constraints._

case class UserForm(name: String, email: String, age: Int)

@Singleton
class FormController @Inject()(val controllerComponents: ControllerComponents)
extends BaseController {

  val userForm: Form[UserForm] = Form(
    mapping(
      "name"  -> nonEmptyText.verifying(minLength(2), maxLength(100)),
      "email" -> email.verifying(nonEmpty),
      "age"   -> number.verifying(min(0), max(150))
    )(UserForm.apply)(UserForm.unapply)
  )

  // Show form
  def showForm: Action[AnyContent] = Action { implicit request =>
    Ok(views.html.userForm(userForm))
  }

  // Process form submission
  def submitForm: Action[AnyContent] = Action { implicit request =>
    userForm.bindFromRequest().fold(
      formWithErrors => {
        BadRequest(views.html.userForm(formWithErrors))
      },
      userData => {
        // Save to database
        Redirect(routes.FormController.showForm()).flashing("success" -> "User created!")
      }
    )
  }
}
```

### Nested and Repeated Form Values

```scala
case class AddressForm(street: String, city: String)
case class RegistrationForm(name: String, addresses: List[AddressForm])

val registrationForm: Form[RegistrationForm] = Form(
  mapping(
    "name" -> nonEmptyText,
    "addresses" -> list(
      mapping(
        "street" -> nonEmptyText,
        "city"   -> nonEmptyText
      )(AddressForm.apply)(AddressForm.unapply)
    )
  )(RegistrationForm.apply)(RegistrationForm.unapply)
)
```

## Database — Evolutions

```sql
-- conf/evolutions/default/1.sql

-- +Ups
CREATE TABLE users (
  id    BIGSERIAL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE posts (
  id      BIGSERIAL PRIMARY KEY,
  title   VARCHAR(500) NOT NULL,
  user_id BIGINT REFERENCES users(id)
);

-- +Downs
DROP TABLE posts;
DROP TABLE users;
```

### Evolutions Configuration

```hocon
# application.conf
play.evolutions {
  db.default.enabled = true
  db.default.autoApply = false    # true for dev, false for prod
  db.default.autoApplyDowns = false
}
```

## Database — Slick Query Patterns

```scala
import slick.jdbc.PostgresProfile.api._
import scala.concurrent.{ExecutionContext, Future}

class PostRepository @Inject()(protected val db: Database)(implicit ec: ExecutionContext) {
  private val posts = TableQuery[PostTable]

  // Filtering
  def findByAuthor(authorId: Long): Future[Seq[Post]] =
    db.run(posts.filter(_.authorId === authorId).result)

  // Pagination
  def list(page: Int, pageSize: Int): Future[Seq[Post]] =
    db.run(posts.drop(page * pageSize).take(pageSize).result)

  // Sorting
  def listRecent: Future[Seq[Post]] =
    db.run(posts.sortBy(_.createdAt.desc).result)

  // Join
  def withAuthors: Future[Seq[(Post, User)]] =
    db.run(posts.join(users).on(_.authorId === _.id).result)

  // Insert returning ID
  def insert(post: Post): Future[Post] =
    db.run((posts returning posts.map(_.id)
      into ((p, id) => p.copy(id = id))) += post)

  // Update
  def updateTitle(id: Long, title: String): Future[Int] =
    db.run(posts.filter(_.id === id).map(_.title).update(title))

  // Delete
  def delete(id: Long): Future[Int] =
    db.run(posts.filter(_.id === id).delete)
}
```

### Slick Configuration

```hocon
# application.conf
slick.dbs.default {
  profile = "slick.jdbc.PostgresProfile$"
  db {
    driver = "org.postgresql.Driver"
    url = "jdbc:postgresql://localhost/mydb"
    user = "user"
    password = "pass"
    connectionPool = "HikariCP"
    numThreads = 20
    maxConnections = 30
  }
}
```
