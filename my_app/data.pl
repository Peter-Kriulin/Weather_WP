use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojolicious::Validator;

# Индексный роут
get '/' => sub {
    my $c = shift;
    $c->render(template => 'index', weather => undef, error => undef);
};

# Обработка данных от пользователя
post '/weather' => sub {
    my $c = shift; 

    my $latitude = $c->param('latitude');   # Получение значения широты
    my $longitude = $c->param('longitude'); # Получение значения долготы
    my $city = $c->param('city');           # Получение названия города
    my $temp_unit = $c->param('temperature'); # Получение единицы измерения температуры
    my $wind_speed_unit = $c->param('wind_speed'); # Получение единицы измерения скорости ветра

    # Валидация входящих параметров для широты и долготы
    if ($latitude || $longitude) {
        my $validator = Mojolicious::Validator->new; # Создаем новый объект для валидации
        my $validation = $validator->validation; # Создание объекта валидации

        $validation->input({ latitude => $latitude, longitude => $longitude });# Добавление данных для валидации
        $validation->required('latitude')->like(qr/^-?\d+(\.\d+)?$/);# Определение правил валидации для широты
        $validation->required('longitude')->like(qr/^-?\d+(\.\d+)?$/);# Определение правил валидации для долготы

        if ($validation->has_error) {
            return $c->render(template => 'index', error => 'Error: неверный тип координат!', weather => undef);# Если False - Ошибка ввода координат!
        }       
    }
    # Создание нового объекта, для выполнения HTTP-запросов
    my $ua = Mojo::UserAgent->new; 

    # Если пользователь вводит название города, выполняется запрос к API для получения координат
    if ($city) {
        my $geo_url = "https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&language=en&format=json"; # Формируем url, для получения координат города
        my $geo_res = $ua->get($geo_url)->result; # Выполняем GET запрос к сформированному URL. Получаем ответ

        # Проверяем успешен ли запрос и есть ли результаты
        if ($geo_res->is_success && $geo_res->json->{results} && @{$geo_res->json->{results}}) {
            $latitude = $geo_res->json->{results}[0]{latitude};  # Извлекаем полученные значения для широты
            $longitude = $geo_res->json->{results}[0]{longitude}; # Извлекаем полученные значения для долготы
        } else {
            return $c->render(template => 'index', error => 'Error: город не найден или не существует!', weather => undef); # Если не удалось извлечь данные "Ошибка: город не найден или его не существует!"
        }
    }
    # Если определена широта и долгота
    if (defined $latitude && defined $longitude) {
        my $weather_url = "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&hourly=temperature_2m,wind_speed_10m&temperature_unit=$temp_unit&wind_speed_unit=$wind_speed_unit";#Формируем url, для запроса к погодному api 
        my $weather_res = $ua->get($weather_url)->result; #Делаем get запрос к url и получаем результат
    # Проверяем успешность запроса 
        if ($weather_res->is_success) {
            my $weather_data = $weather_res->json;
            $c->render(template => 'index', weather => $weather_data, temp_unit => $temp_unit, wind_speed_unit => $wind_speed_unit);# Если True - извлекаем данные из погодного api
        } else {
            $c->render(template => 'index', error => 'Error: не удалось получить данные о погоде!', weather => undef);# Если False -'Ошибка: не удалось получить данные о погоде!'
        }
    }
};

app->start;
