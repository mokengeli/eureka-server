# Étape de build
FROM maven:3.9.6-eclipse-temurin-21-jammy AS build
WORKDIR /app

# Copie et installation des dépendances
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copie du code source et compilation
COPY src ./src
RUN mvn package -DskipTests

# Extraction dynamique de la version
RUN APP_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout) \
    && echo "Version extraite: $APP_VERSION" \
    && cp target/eureka-server-$APP_VERSION.jar target/app.jar

# Étape finale
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Création d'un utilisateur non-root
RUN addgroup --system appuser && adduser --system --ingroup appuser appuser
USER appuser:appuser

# Copie du JAR compilé
COPY --from=build /app/target/app.jar ./app.jar

# Copie de tous les fichiers de configuration
COPY src/main/resources/application*.yml ./config/

# Exposer le port Eureka standard
EXPOSE 8761

# Variables d'environnement avec valeurs par défaut
# Remarque: contrairement aux autres services, Eureka peut fonctionner avec des valeurs par défaut
ENV SERVER_PORT="8761" \
    EUREKA_HOSTNAME="eureka-server" \
    TIME_ZONE="GMT+01:00" \
    SPRING_PROFILES_ACTIVE="dev" \
    REGISTER_WITH_EUREKA="false" \
    FETCH_REGISTRY="false" \
    WAIT_TIME_SYNC="0" \
    PREFER_IP="true" \
    ACTUATOR_ENDPOINTS="*" \
    EUREKA_LOG_LEVEL="INFO"

# Point d'entrée
ENTRYPOINT ["java", "-jar", "app.jar", "--spring.profiles.active=${SPRING_PROFILES_ACTIVE}",\
            "--spring.config.location=file:./config/"]

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:${SERVER_PORT}/actuator/health || exit 1