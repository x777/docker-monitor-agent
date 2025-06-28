# Docker Monitor Agent

Легковесный агент для мониторинга Docker контейнеров. Предоставляет REST API для получения информации о контейнерах, метрик и управления ими.

## Возможности

- 📊 Мониторинг контейнеров в реальном времени
- 📈 Метрики CPU, памяти, сети
- 🔧 Управление контейнерами (start/stop/restart/pause/unpause)
- 📝 Просмотр логов контейнеров
- 🔐 Безопасная аутентификация по токену
- 🏥 Health check эндпоинты

## Быстрый старт

### 1. Клонирование и настройка

```bash
# Скопируйте файл конфигурации
cp env.example .env

# Отредактируйте .env файл
nano .env
```

### 2. Настройка переменных окружения

```bash
# Обязательно измените токен агента
AGENT_TOKEN=your-secure-token-change-this

# Порт для агента (по умолчанию 8080)
AGENT_PORT=8080
```

### 3. Запуск с Docker Compose

```bash
# Сборка и запуск
docker-compose up -d

# Просмотр логов
docker-compose logs -f agent

# Остановка
docker-compose down
```

### 4. Тестирование

```bash
# Установите зависимости для тестирования
pip install -r requirements.txt

# Запустите тест
python test_agent.py
```

## API Эндпоинты

### Без аутентификации

- `GET /` - Информация об агенте
- `GET /health` - Проверка состояния

### С аутентификацией (Bearer Token)

- `GET /containers` - Список всех контейнеров
- `GET /containers?name_filter=pattern` - Фильтрация контейнеров по имени
- `GET /monitored-containers?names=name1,name2` - Получение конкретных контейнеров
- `GET /monitored-containers/metrics?names=name1,name2` - Метрики конкретных контейнеров
- `GET /containers/{id}/metrics` - Метрики контейнера
- `GET /containers/{id}/logs` - Логи контейнера
- `POST /containers/{id}/action` - Действия с контейнером
- `GET /metrics` - Метрики сервера
- `GET /info` - Информация о Docker

## Фильтрация контейнеров

### Поддерживаемые паттерны:

- **Точное совпадение**: `nginx` - найдет контейнер с именем "nginx"
- **Содержит**: `*web*` - найдет контейнеры, содержащие "web" в имени
- **Начинается с**: `app*` - найдет контейнеры, начинающиеся с "app"
- **Заканчивается на**: `*db` - найдет контейнеры, заканчивающиеся на "db"
- **Несколько паттернов**: `app*,*db,nginx` - найдет контейнеры по всем паттернам

## Примеры использования

### Получение списка контейнеров

```bash
curl -H "Authorization: Bearer your-token" \
     http://localhost:8080/containers
```

### Фильтрация контейнеров по имени

```bash
# Все контейнеры, содержащие "web"
curl -H "Authorization: Bearer your-token" \
     http://localhost:8080/containers?name_filter=*web*

# Контейнеры, начинающиеся с "app"
curl -H "Authorization: Bearer your-token" \
     http://localhost:8080/containers?name_filter=app*
```

### Мониторинг конкретных контейнеров

```bash
# Получение информации о конкретных контейнерах
curl -H "Authorization: Bearer your-token" \
     "http://localhost:8080/monitored-containers?names=nginx,app-web,postgres-db"

# Получение метрик конкретных контейнеров
curl -H "Authorization: Bearer your-token" \
     "http://localhost:8080/monitored-containers/metrics?names=nginx,app-web,postgres-db"
```

### Остановка контейнера

```bash
curl -X POST \
     -H "Authorization: Bearer your-token" \
     -H "Content-Type: application/json" \
     -d '{"action": "stop"}' \
     http://localhost:8080/containers/container-id/action
```

## Устранение неполадок

### Проблема: 503 Service Unavailable в /health

**Причина:** Агент не может подключиться к Docker daemon

**Решение:**
1. Убедитесь, что Docker socket доступен: `ls -la /var/run/docker.sock`
2. Проверьте права доступа: `sudo chmod 666 /var/run/docker.sock`
3. Добавьте пользователя в группу docker: `sudo usermod -aG docker $USER`

### Проблема: 404 Not Found для всех эндпоинтов

**Причина:** Агент не запущен или неправильный порт

**Решение:**
1. Проверьте статус контейнера: `docker-compose ps`
2. Просмотрите логи: `docker-compose logs agent`
3. Убедитесь, что порт правильно проброшен

### Проблема: 401 Unauthorized

**Причина:** Неправильный токен аутентификации

**Решение:**
1. Проверьте переменную `AGENT_TOKEN` в `.env`
2. Убедитесь, что токен передается в заголовке `Authorization: Bearer <token>`

## Развертывание в продакшене

### 1. Безопасность

- Измените токен агента на сложный
- Используйте HTTPS в продакшене
- Ограничьте доступ к порту агента
- Регулярно обновляйте зависимости

### 2. Мониторинг

- Настройте мониторинг health check эндпоинта
- Логируйте все запросы к API
- Настройте алерты при недоступности агента

### 3. Масштабирование

- Для множественных серверов используйте балансировщик нагрузки
- Настройте централизованный сбор логов
- Используйте Docker Swarm или Kubernetes для оркестрации

## Разработка

### Локальная разработка

```bash
# Установка зависимостей
pip install -r requirements.txt

# Запуск в режиме разработки
python src/main.py
```

### Тестирование

```bash
# Запуск тестов
python test_agent.py

# Проверка health check
curl http://localhost:8080/health
```

## Лицензия

MIT License