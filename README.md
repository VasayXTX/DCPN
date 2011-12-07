### Описание

Проект представляет собой небольшое приложение для распределенного вычисления простых чисел, имеющее клиент-серверную архитектуру.
Для определение простоты числа используется [тест Миллера-Рабина](http://en.wikipedia.org/wiki/Miller%E2%80%93Rabin_primality_test).
Проект реализован на языке ruby 1.9 (версия используемого интерпретатора 1.9.3p0).
Для хранения результатов используется NoSQL база данных, MongoDB.

### Содержимое проекта

#### Сервер
+ Gemfile
+ server.rb
+ generators.rb
+ client_container.rb
+ Rakefile
+ configure.yml

#### Клиент
+ Gemfile
+ client.rb
+ sys_info.rb
+ primes_search_engine.rb
+ configure.yaml
+ configure_rr.yaml

### Используемые инструменты (gem'ы)
+ [eventmachine](https://github.com/eventmachine/eventmachine)
+ [mongoid](https://github.com/mongoid/mongoid)
+ [ohai](https://github.com/opscode/ohai)
+ [progressbar](https://github.com/peleteiro/progressbar)

### Руководство по использованию

#### Сервер
    ruby server.rb          #Запуск сервера с параметра (начальной значение и шаг диапазона), берутся из configure.yml
    ruby server.rb 1 100000 #Запуск сервера с явно заданными параметрами

#### Клиент
    ruby client.rb                  #Запуск клиента с параметрами из configure.yml
    ruby client.rb configure_rr.yml #Запуск клиента с параметрами из configure_rr.yml

### Описание файлов конфигураций

#### Сервер. Содержимое файла configure.yml (yaml формат)
    params:
      host: ''              #Адрес хоста. Если пустая строка, то localhost
      port: 4567            #Номер порта
      range_start: 1        #Начальное значение, 
      range_step: 1000000   #Шаг диапазона
    round_robin:
      interval: 10          #Интервал для обмена данными (в секундах)
      clients_num: 2        #Минимальное количество клиентов, необходимое для выполнения Round-Robin'а
    db:                     #Параметры СУБД
      name: 'primes'      
      host: 'localhost'
  
#### Клиент
    server:
      host: 'localhost'     #Адрес сервера
      port: 4567            #Номер порт на сервере
    params:
      host: 'localhost'     #Адрес хоста клиента
      login: 'Vanya'        #Логин клиента
      range_nums: 1         #Количество диапазонов, которые клиент будет брать для расчета
      process_priority: 19  #Приоритет процесса
    round_robin:            #Параметры для Round-Robin'а (опционально).
      port: 9001            #Номер порта для обмена данными

