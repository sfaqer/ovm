#Использовать 1commands
#Использовать fs
#Использовать tempfiles
#Использовать logos

Перем ЭтоWindows;
Перем Лог;

// Установка указанной версии OneScript.
// Допустимо использовать трех-разрядные номера версий и шорткаты dev и stable
//
// Параметры:
//   ВерсияКУстановке - Строка - Имя версии, которую необходимо установить
//   АлиасВерсии - Строка - Имя каталога, в который необходимо установить OneScript. По умолчанию совпадает и
//                          ВерсияКУстановке
//   ОчищатьКаталогУстановки - Булево - Необходимость очистки каталога, в который устанавливается версия.
//
Процедура УстановитьOneScript(
	Знач ВерсияКУстановке, 
	Знач АлиасВерсии = "", 
	Знач ОчищатьКаталогУстановки = Истина
) Экспорт
	
	Лог.Информация("Установка OneScript %1...", ВерсияКУстановке);
	
	Если НЕ ЗначениеЗаполнено(АлиасВерсии) Тогда
		АлиасВерсии = ВерсияКУстановке;
	КонецЕсли;

	ПроверитьКорректностьПереданнойВерсии(ВерсияКУстановке);
	
	КаталогУстановки = ПараметрыOVM.КаталогУстановкиПоУмолчанию();
	КаталогУстановкиВерсии = ОбъединитьПути(КаталогУстановки, АлиасВерсии);
	
	ФС.ОбеспечитьКаталог(КаталогУстановки);
	Если ОчищатьКаталогУстановки Тогда
		ФС.ОбеспечитьПустойКаталог(КаталогУстановкиВерсии);
	Иначе
		ФС.ОбеспечитьКаталог(КаталогУстановкиВерсии);
	КонецЕсли;

	Лог.Отладка("Каталог установки версии: %1", КаталогУстановкиВерсии);

	Попытка
		ФайлУстановщика = СкачатьФайлУстановщика(ВерсияКУстановке);
	
		УстановитьOneScriptИзZipАрхива(ФайлУстановщика, КаталогУстановкиВерсии);
		ДобавитьSHСкриптыПриНеобходимости(КаталогУстановкиВерсии);
	Исключение
		УдалитьФайлы(КаталогУстановкиВерсии);
		ВызватьИсключение ОписаниеОшибки();	
	КонецПопытки;

	Лог.Информация("Установка OneScript %1 завершена", ВерсияКУстановке);
	Лог.Информация("");

КонецПроцедуры

Функция СкачатьФайлУстановщика(Знач ВерсияКУстановке)
	
	Лог.Информация("Скачиваю установщик версии %1...", ВерсияКУстановке);

	ПутьКСохраняемомуФайлу = ВременныеФайлы.НовоеИмяФайла("zip");
	
	АдресСайтаОСкрипт = ПараметрыOVM.АдресСайтаОСкрипт();

	СерверПрокси = ПараметрыOVM.ЗначениеНастройки("proxy.server");
	ИспользоватьПрокси = ПараметрыOVM.ЗначениеНастройки("proxy.use");

	Если ИспользоватьПрокси = "true" Тогда
		Если Не ЗначениеЗаполнено(СерверПрокси) Тогда
			Лог.Отладка("Использую системный прокси");
			Прокси = Новый ИнтернетПрокси(Истина);
		ИначеЕсли ЗначениеЗаполнено(СерверПрокси) Тогда
			Лог.Отладка("Использую прокси %1", ПараметрыOVM.ЗначениеНастройки("proxy.server"));
			Прокси = Новый ИнтернетПрокси();
			Прокси.Установить("http",
				ПараметрыOVM.ЗначениеНастройки("proxy.server"),
				ПараметрыOVM.ЗначениеНастройки("proxy.port"),
				ПараметрыOVM.ЗначениеНастройки("proxy.user"),
				ПараметрыOVM.ЗначениеНастройки("proxy.password"),
				ПараметрыOVM.ЗначениеНастройки("proxy.osAuthentication"));

			Прокси.Установить("https",
				ПараметрыOVM.ЗначениеНастройки("proxy.server"),
				ПараметрыOVM.ЗначениеНастройки("proxy.port"),
				ПараметрыOVM.ЗначениеНастройки("proxy.user"),
				ПараметрыOVM.ЗначениеНастройки("proxy.password"),
				ПараметрыOVM.ЗначениеНастройки("proxy.osAuthentication"));
		КонецЕсли;
	Иначе
		Лог.Отладка("Прокси не используется");
		Прокси = Неопределено;
	КонецЕсли;

	Таймаут = 10;
	Соединение = Новый HTTPСоединение(
		АдресСайтаОСкрипт,
		,
		,
		,
		Прокси,
		Таймаут
	);
	
	Ресурс = ПолучитьПутьКСкачиваниюФайла(ВерсияКУстановке);
	Запрос = Новый HTTPЗапрос(Ресурс);
	
	Лог.Отладка("Сервер: %1. Ресурс: %2", Соединение.Сервер, Ресурс);

	Ответ = Соединение.Получить(Запрос, ПутьКСохраняемомуФайлу);
	Лог.Отладка("Код состояния: %1", Ответ.КодСостояния);

	Лог.Информация("Скачивание завершено");

	HTTP_OK = 200;
	Если Ответ.КодСостояния <> HTTP_OK Тогда
		Лог.Ошибка(
			"Ошибка скачивания установщика. Текст ответа: 
			|%1", 
			Ответ.ПолучитьТелоКакСтроку()
		);
		ВызватьИсключение Ответ.КодСостояния;
	КонецЕсли;
	
	Лог.Отладка("Файл установщика скачан: %1", ПутьКСохраняемомуФайлу);
	
	Возврат ПутьКСохраняемомуФайлу;
	
КонецФункции

Процедура УстановитьOneScriptИзZipАрхива(Знач ПутьКФайлуУстановщика, Знач КаталогУстановкиВерсии)
	
	Лог.Информация("Распаковка OneScript...");

	ЧтениеZIPФайла = Новый ЧтениеZipФайла(ПутьКФайлуУстановщика);
	ЧтениеZIPФайла.ИзвлечьВсе(КаталогУстановкиВерсии);
	ЧтениеZIPФайла.Закрыть();
	
КонецПроцедуры

Процедура ДобавитьSHСкриптыПриНеобходимости(Знач КаталогУстановкиВерсии)
	
	Если ЭтоWindows Тогда
		Возврат;
	КонецЕсли;
	
	ПутьКСкрипту = ОбъединитьПути(КаталогУстановкиВерсии, "bin", "oscript");
	ТекстСкрипта = 
	"#!/bin/sh
	|dirpath=`dirname $0`
	|mono $dirpath/oscript.exe ""$@""
	|";
	
	ДобавитьShСкрипт(ПутьКСкрипту, ТекстСкрипта);

	ПутьКСкрипту = ОбъединитьПути(КаталогУстановкиВерсии, "bin", "opm");
	ТекстСкрипта = 
	"#!/bin/sh
	|dirpath=`dirname $0`
	|opmpath=$dirpath/../lib/opm/src/opm.os
	|if [ ! -f ""$opmpath"" ]; then
	|	opmpath=$dirpath/../lib/opm/src/cmd/opm.os
	|fi
	|oscript ""$opmpath"" ""$@""
	|";
	
	ДобавитьShСкрипт(ПутьКСкрипту, ТекстСкрипта);

КонецПроцедуры

Процедура ДобавитьShСкрипт(Знач ПутьКСкрипту, Знач ТекстСкрипта)
	
	Лог.Информация("Создание sh-скрипта %1...", Новый Файл(ПутьКСкрипту).ИмяБезРасширения);

	Лог.Отладка("Путь с sh-скрипту: %1", ПутьКСкрипту);
	
	Лог.Отладка(
		"Текст скрипта: 
		|%1",
		ТекстСкрипта
	);
	
	Если ФС.ФайлСуществует(ПутьКСкрипту) Тогда
		Лог.Отладка("sh-скрипт уже существует");
		Возврат;
	КонецЕсли;

	ЗаписьТекста = Новый ЗаписьТекста(ПутьКСкрипту, КодировкаТекста.UTF8NoBOM, , , Символы.ПС);
	
	ЗаписьТекста.Записать(ТекстСкрипта);
	ЗаписьТекста.Закрыть();
	
	Лог.Отладка("Установка флага выполнения...");

	Команда = Новый Команда;
	Команда.УстановитьКоманду("chmod");
	Команда.ДобавитьПараметр("+x");
	Команда.ДобавитьПараметр(ПутьКСкрипту);
	Команда.УстановитьПравильныйКодВозврата(0);
	
	Команда.Исполнить();
	Лог.Отладка(Команда.ПолучитьВывод());

КонецПроцедуры

Процедура ПроверитьКорректностьПереданнойВерсии(Знач ВерсияКУстановке)
	Если СтрРазделить(ВерсияКУстановке, ".").Количество() <> ПараметрыOVM.КоличествоРазрядовВНомереВерсии()
		И НРег(ВерсияКУстановке) <> "stable"
		И НРег(ВерсияКУстановке) <> "dev" Тогда
		
		Лог.Ошибка("Версия имеет некорректный формат");

		ВызватьИсключение ВерсияКУстановке;
	КонецЕсли;
КонецПроцедуры

Функция ПолучитьПутьКСкачиваниюФайла(Знач ВерсияКУстановке)
	
	Если СтрРазделить(ВерсияКУстановке, ".").Количество() = ПараметрыOVM.КоличествоРазрядовВНомереВерсии() Тогда
		КаталогВерсии = СтрЗаменить(ВерсияКУстановке, ".", "_");
	ИначеЕсли НРег(ВерсияКУстановке) = "stable" Тогда
		КаталогВерсии = "latest";
	ИначеЕсли НРег(ВерсияКУстановке) = "dev" Тогда
		КаталогВерсии = "night-build";
	Иначе
		ВызватьИсключение "Ошибка получения пути к файлу по версии";
	КонецЕсли;
	ИмяФайла = "zip";
	
	ЧастиПути = Новый Массив;
	ЧастиПути.Добавить("downloads");
	ЧастиПути.Добавить(КаталогВерсии);
	Если ПараметрыOVM.Это64битнаяОперационнаяСистема() 
		И НЕ ПараметрыOVM.Использовать32бита() Тогда
		ЧастиПути.Добавить("x64");
	КонецЕсли;
	ЧастиПути.Добавить(ИмяФайла);

	Ресурс = СтрСоединить(ЧастиПути, "/");
	Возврат Ресурс;
	
КонецФункции

СистемнаяИнформация = Новый СистемнаяИнформация;
ЭтоWindows = Найти(ВРег(СистемнаяИнформация.ВерсияОС), "WINDOWS") > 0;

Лог = ПараметрыOVM.ПолучитьЛог();
