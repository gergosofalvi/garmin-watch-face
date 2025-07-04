using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;

import Toybox.Lang;

typedef HttpErrorData as {
	"httpError" as Number
};

typedef CityLocalTimeSuccessResponse as {
	"requestCity" as String,
	"city" as String,
	"current" as {
		"gmtOffset" as Number,
		"dst" as Boolean
	},
	"next" as {
		"when" as Number,
		"gmtOffset" as Number,
		"dst" as Boolean
	}
};

typedef CityLocalTimeErrorResponse as {
	"requestCity" as String,
	"error" as {
		"code" as Number,
		"message" as String
	}
};

typedef CityLocalTimeResponse as CityLocalTimeSuccessResponse or CityLocalTimeErrorResponse;

typedef CityLocalTimeData as CityLocalTimeResponse;

typedef OpenWeatherMapCurrentSuccessResponse as {
	"coord" as {
		"lon" as Number,
		"lat" as Number
	},
	"weather" as Array<{
		"id" as Number,
		"main" as String,
		"description" as String,
		"icon" as String
	}>,
	"base" as String,
	"main" as {
		"temp" as Number,
		"pressure" as Number,
		"humidity" as Number,
		"temp_min" as Number,
		"temp_max" as Number
	},
	"visibility" as Number,
	"wind" as {
		"speed" as Number,
		"deg" as Number
	},
	"clouds" as {
		"all" as Number
	},
	"dt" as Number,
	"sys" as {
		"type" as Number,
		"id" as Number,
		"message" as Number,
		"country" as String,
		"sunrise" as Number,
		"sunset" as Number,
	},
	"id" as Number,
	"name" as String,
	"cod" as Number
};

typedef OpenWeatherMapCurrentErrorResponse as {
	"cod" as Number,
	"message" as String
};

typedef OpenWeatherMapCurrentResponse as OpenWeatherMapCurrentSuccessResponse or OpenWeatherMapCurrentErrorResponse;

typedef OpenWeatherMapCurrentData as {
	"cod" as Number,
	"lat" as Number,
	"lon" as Number,
	"dt" as Number,
	"temp" as Number,
	"humidity" as Number,
	"icon" as String
};

(:background)
class BackgroundService extends Sys.ServiceDelegate {
	
	(:background_method)
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}

	// Read pending web requests, and call appropriate web request function.
	// This function determines priority of web requests, if multiple are pending.
	// Pending web request flag will be cleared only once the background data has been successfully received.
	(:background_method)
	function onTemporalEvent() {
		//Sys.println("onTemporalEvent");
		var pendingWebRequests = getStorageValue("PendingWebRequests") as PendingWebRequests?;
		if (pendingWebRequests != null) {

			// 1. City local time.
			if (pendingWebRequests["CityLocalTime"] != null) {
				makeWebRequest(
					"https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec",
					{
						"city" => getPropertyValue("LocalTimeInCity")
					},
					method(:onReceiveCityLocalTime)
				);

			// 2. Weather.
			} else if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
				var owmKeyOverride = getPropertyValue("OWMKeyOverride");
				makeWebRequest(
					"https://api.openweathermap.org/data/2.5/weather",
					{
						"lat" => getStorageValue("LastLocationLat"),
						"lon" => getStorageValue("LastLocationLng"),

						// Polite request from Vince, developer of the sFlvWatchFace Watch Face:
						//
						// Please do not abuse this API key, or else I will be forced to make thousands of users of sFlvWatchFace
						// sign up for their own Open Weather Map free account, and enter their key in settings - a much worse
						// user experience for everyone.
						//
						// sFlvWatchFace has been registered with OWM on the Open Source Plan, which lifts usage limits for free, so
						// that everyone benefits. However, these lifted limits only apply to the Current Weather API, and *not*
						// the One Call API. Usage of this key for the One Call API risks blocking the key for everyone.
						//
						// If you intend to use this key in your own app, especially for the One Call API, please create your own
						// OWM account, and own key. You should be able to apply for the Open Source Plan to benefit from the same
						// lifted limits as sFlvWatchFace. Thank you.
						"appid" => ((owmKeyOverride != null) && (owmKeyOverride.length() == 0)) ? "2651f49cb20de925fc57590709b86ce6" : owmKeyOverride,

						"units" => "metric" // Celcius.
					},
					method(:onReceiveOpenWeatherMapCurrent)
				);
			}
		} /* else {
			Sys.println("onTemporalEvent() called with no pending web requests!");
		} */
	}

	// Sample time zone data:
	/*
	{
	"requestCity":"london",
	"city":"London",
	"current":{
		"gmtOffset":3600,
		"dst":true
		},
	"next":{
		"when":1540688400,
		"gmtOffset":0,
		"dst":false
		}
	}
	*/

	// Sample error when city is not found:
	/*
	{
	"requestCity":"atlantis",
	"error":{
		"code":2, // CITY_NOT_FOUND
		"message":"City \"atlantis\" not found."
		}
	}
	*/
	(:background_method)
	function onReceiveCityLocalTime(responseCode as Number, data as CityLocalTimeResponse?) {

		// HTTP failure: return responseCode.
		// Otherwise, return data response.
		if (responseCode != 200) {
			data = {
				"httpError" => responseCode
			};
		}

		Bg.exit({
			"CityLocalTime" => data as CityLocalTimeData or HttpErrorData
		});
	}

	// Sample invalid API key:
	/*
	{
		"cod":401,
		"message": "Invalid API key. Please see http://openweathermap.org/faq#error401 for more info."
	}
	*/

	// Sample current weather:
	/*
	{
		"coord":{
			"lon":-0.46,
			"lat":51.75
		},
		"weather":[
			{
				"id":521,
				"main":"Rain",
				"description":"shower rain",
				"icon":"09d"
			}
		],
		"base":"stations",
		"main":{
			"temp":281.82,
			"pressure":1018,
			"humidity":70,
			"temp_min":280.15,
			"temp_max":283.15
		},
		"visibility":10000,
		"wind":{
			"speed":6.2,
			"deg":10
		},
		"clouds":{
			"all":0
		},
		"dt":1540741800,
		"sys":{
			"type":1,
			"id":5078,
			"message":0.0036,
			"country":"GB",
			"sunrise":1540709390,
			"sunset":1540744829
		},
		"id":2647138,
		"name":"Hemel Hempstead",
		"cod":200
	}
	*/
	(:background_method)
	function onReceiveOpenWeatherMapCurrent(responseCode as Number, data as OpenWeatherMapCurrentResponse?) {
		var result;
		
		// Useful data only available if result was successful.
		// Filter and flatten data response for data that we actually need.
		// Reduces runtime memory spike in main app.
		if (responseCode == 200) {
			data = (data as OpenWeatherMapCurrentSuccessResponse);
			result = {
				"cod" => data["cod"],
				"lat" => data["coord"]["lat"],
				"lon" => data["coord"]["lon"],
				"dt" => data["dt"],
				"temp" => data["main"]["temp"],
				"humidity" => data["main"]["humidity"],
				"icon" => data["weather"][0]["icon"]
			};

		// HTTP error: do not save.
		} else {
			result = {
				"httpError" => responseCode
			};
		}

		Bg.exit({
			"OpenWeatherMapCurrent" => result as OpenWeatherMapCurrentData or HttpErrorData
		});
	}

	(:background_method)
	function makeWebRequest(url, params, callback) {
		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};

		Comms.makeWebRequest(url, params, options, callback);
	}
}
