suffix=''

# xcrun simctl delete "Shop_iPhone_14_US_2${suffix}"
xcrun simctl delete "Shop_iPhone_16_Pro_Max${suffix}"
xcrun simctl delete "Shop_iPhone_16${suffix}"
xcrun simctl delete "Shop_iPhone_15_Pro${suffix}"
xcrun simctl delete "Shop_iPhone_17${suffix}"


# xcrun simctl create "Shop_iPhone_16_Pro_Max${suffix}" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max" com.apple.CoreSimulator.SimRuntime.iOS-18-1
xcrun simctl create "Shop_iPhone_16_Pro_Max${suffix}" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max" com.apple.CoreSimulator.SimRuntime.iOS-26-0
xcrun simctl create Shop_iPhone_16${suffix} "iPhone 16" com.apple.CoreSimulator.SimRuntime.iOS-26-0
xcrun simctl create Shop_iPhone_15_Pro${suffix} "iPhone 15 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-0
xcrun simctl create Shop_iPhone_17${suffix} "iPhone 17" com.apple.CoreSimulator.SimRuntime.iOS-26-0

# xcrun simctl delete "F8A00FB8-771B-4E71-B7B5-7E91F2AD4D4A"
# xcrun simctl create Shop_iPhone_16_Plus "iPhone 16 Plus" com.apple.CoreSimulator.SimRuntime.iOS-26-0