# Research notes: on device bike fit from an iPhone camera (Apple CV stack and markerless accuracy)

Date: 2026-11-03. Researcher: Claude subagent. Scope: technical feasibility only (Vision, ARKit, AVFoundation, CoreMotion, LiDAR, Core ML model options, published accuracy of markerless 2D pose for sagittal knee and hip angles, cycling specific validations, perspective and clothing effects, frame rate and capture).

Method note: Apple developer doc pages are JavaScript rendered; the facts below were read from Apple's own documentation JSON endpoint (developer.apple.com/tutorials/data/documentation/...), which serves the same content as the HTML pages linked. WWDC transcripts were read from the session pages. Papers were read from publisher pages, PubMed abstracts (eutils) and Europe PMC full text XML. Web search budget ran out before I could look for Vision framework benchmark numbers in ms, lighting studies and a Theia clothing study by Keller; those remain open questions.

---

## 1. Apple Vision 2D body pose (VNDetectHumanBodyPoseRequest)

- Availability: iOS 14.0, iPadOS 14.0, Mac Catalyst 14.0, macOS 11.0, tvOS 14.0, visionOS 1.0. "A request that detects a human body pose." Result type VNHumanBodyPoseObservation. Only one revision exists (VNDetectHumanBodyPoseRequestRevision1).
  https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest
- Joints (VNHumanBodyPoseObservation.JointName), 19 total, grouped by Apple as: Head: nose, leftEye, rightEye, leftEar, rightEar, neck. Arms: leftShoulder, leftElbow, leftWrist, rightShoulder, rightElbow, rightWrist. Waist: root. Legs: leftHip, leftKnee, leftAnkle, rightHip, rightKnee, rightAnkle. No foot, toe or heel point, so the ankle angle cannot be built from Vision 2D alone (hip, knee, ankle are enough for knee angle at BDC; hip angle needs shoulder).
  https://developer.apple.com/documentation/vision/vnhumanbodyposeobservation/jointname
- Sample article "Detecting Human Body Poses in Images": "Starting in iOS 14 and macOS 11, Vision adds the powerful new ability to identify human body poses. It does so by detecting up to 19 unique body points". Points come back as VNRecognizedPoint (normalized location, lower left origin, plus a confidence value per point).
  https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images
  https://developer.apple.com/documentation/vision/vnrecognizedpoint
- WWDC20 "Detect Body and Hand Pose with Vision" (session 10653) stated limitations, quoted from transcript: "If the people on the scene are bent over or upside down, the body pose algorithm will not perform as well." "the pose might not be determinable due to obstructive flowing clothing." "if one person is partially occluding another in the view, it is possible for the algorithm to get confused." "the results may get worse if the subject is close to the edges of the screen." Also: "Vision provides a confidence value per point while ARKit does not." Multi person supported. Performance: "the latest and greatest devices might be able to keep up with the camera stream while performing inference ... older devices will not." Sample code thresholds: observation.confidence > 0.6, point.confidence > 0.1. Note for bike fit: a rider in the drops or aero bars is a "bent over" pose, which Apple names as a degraded case.
  https://developer.apple.com/videos/play/wwdc2020/10653/
- WWDC21 "Detect people, faces, and poses using Vision" (10040): body pose still revision 1 only; person segmentation guidance (each person at least half the image height, good contrast).
  https://developer.apple.com/videos/play/wwdc2021/10040/

## 2. Apple Vision 3D body pose (VNDetectHumanBodyPose3DRequest)

- Availability iOS 17.0, iPadOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0. "A request that detects points on human bodies in 3D space, relative to the camera." "If the system allows it, the request uses AVDepthData information to improve the accuracy."
  https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest
- Joint names (17): topHead, centerHead, centerShoulder, leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist, leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle, root, spine.
  https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/jointname
- Observation API: recognizedPoint, recognizedPoints, pointInImage(_:) ("A projection of the 3D position onto the original 2D image in normalized, lower left origin coordinates"), parentJointName, bodyHeight ("The estimated human body height, in meters." accurate if heightEstimation is .measured, otherwise a reference height), cameraOriginMatrix ("A transform from the skeleton hip to the camera"), cameraRelativePosition(_:) ("The joint position, in meters").
  https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation
  https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/bodyheight
  https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/pointinimage(_:)
  https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/cameraoriginmatrix
- HeightEstimation enum: .measured = "A technique that uses LiDAR depth data to measure body height, in meters." .reference = "If there's no depth data available, the framework uses a reference height of 1.8 meters."
  https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/heightestimation-swift.enum/measured
  https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/heightestimation-swift.enum/reference
- WWDC23 "Explore 3D body pose and person segmentation in Vision" (111241), transcript: "returns a 3D skeleton with 17 joints"; "position of the 3D joints is returned in meters relative to the captured scene in the real world with an origin at a root joint"; "This initial revision returns one skeleton for the most prominent person detected in the frame"; bodyHeight "will either be a more accurate measured height or a reference height of 1.8 meters"; cameraOriginMatrix is useful because "in real life the camera may not be exactly facing your subject"; depth can be passed via VNImageRequestHandler initializers that take AVDepthData, "LiDAR is powerful because it allows for accurate scale and measurement of the scene." The transcript does not say the whole body must be visible; the task brief's "fully visible" claim could not be confirmed in Apple text I read (open question). The 3D request has no ARKit dependency.
  https://developer.apple.com/videos/play/wwdc2023/111241/
- Implication: without LiDAR depth, 3D joints are scaled to a 1.8 m person, so absolute lengths are wrong but angles are still usable; cameraOriginMatrix gives a direct estimate of camera yaw relative to the rider, which is exactly the perspective error estimate needed.

## 3. ARKit body tracking (ARBodyTrackingConfiguration)

- Availability iOS 13.0 / iPadOS 13.0. "A configuration that tracks human body poses, planar surfaces, and images using the rear-facing camera." Delivers ARBodyAnchor; frameSemantics includes bodyDetection by default which also gives a 2D detectedBody.
  https://developer.apple.com/documentation/arkit/arbodytrackingconfiguration
- ARBodyAnchor: "tracks the movement of a single person"; "A body anchor's transform position defines the world position of the body's hip joint."
  https://developer.apple.com/documentation/arkit/arbodyanchor
- estimatedScaleFactor: "If you set automaticSkeletonScaleEstimationEnabled to true ... ARKit sets this property to a value between 0.0 and 1.0. ARKit must know the height of a person in the camera feed to estimate an accurate world position ... The default body is 1.8 meters tall." (ARSkeletonDefinition.defaultBody3D page says "The default height of this skeleton is 1.66 meters", an inconsistency in Apple's docs.)
  https://developer.apple.com/documentation/arkit/arbodyanchor/estimatedscalefactor
  https://developer.apple.com/documentation/arkit/arskeletondefinition/defaultbody3d
- Device requirement: sample "Capturing Body Motion in 3D": "To run the sample, use an iOS device with an A12 chip or later." ARConfiguration.isSupported page: "All ARKit configurations require an iOS device with an A9 or later processor."
  https://developer.apple.com/documentation/arkit/capturing-body-motion-in-3d
  https://developer.apple.com/documentation/arkit/arconfiguration/issupported
- WWDC19 "Bringing People into AR" (607): "the underlying skeleton that we provide is a very high-fidelity skeleton consisting of 91 joints"; 2D skeleton has 16 joints; "we have made it available on A12 devices and beyond"; runs on the Apple Neural Engine; some joints are not tracked: "the yellow ones are not tracked. They just follow the motion of the closest green parent." So 91 joints does not mean 91 measured joints.
  https://developer.apple.com/videos/play/wwdc2019/607/
- ARSkeleton3D: jointLocalTransforms (offset from parent) and jointModelTransforms (offset from the anchor). ARSkeletonDefinition exposes jointCount, jointNames, parentIndices.
  https://developer.apple.com/documentation/arkit/arskeleton3d
  https://developer.apple.com/documentation/arkit/arskeletondefinition
- ARKit frame rate: ARConfiguration.VideoFormat.framesPerSecond; supportedVideoFormats is ordered higher quality first and differs per device and iOS version.
  https://developer.apple.com/documentation/arkit/arconfiguration/videoformat-swift.class/framespersecond
  https://developer.apple.com/documentation/arkit/arconfiguration/supportedvideoformats
- Trade offs for bike fit: ARKit needs a live session (no offline video), rear camera only, no per joint confidence (WWDC20), single person, and WWDC20 also says ARKit and Vision poses are not interchangeable as model inputs. LiDAR is not required for body tracking (requirement is A12). Side profile with a bicycle: no Apple statement found either way; open question that needs a bench test.

## 4. Depth, scale and camera geometry on iPhone

- ARFrame.sceneDepth (iOS 14): "ARKit samples this distance using the LiDAR scanner"; "ARKit supports scene depth only on LiDAR-capable devices, so call supportsFrameSemantics(_:)". smoothedSceneDepth is a temporally smoothed variant.
  https://developer.apple.com/documentation/arkit/arconfiguration/framesemantics-swift.struct/scenedepth
  https://developer.apple.com/documentation/arkit/arframe/smoothedscenedepth
- AVCaptureDevice.DeviceType.builtInLiDARDepthCamera (iOS 15.4): "The LiDAR camera provides high-quality, high-accuracy depth information by measuring the round trip of an artificial light signal that a laser emits. The device synchronizes and perspective-corrects this data to frames that the YUV camera produces."
  https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtinlidardepthcamera
- Independent LiDAR accuracy: Luetzenburg, Kroon, Bjork 2021, Scientific Reports: "accurate high-resolution models of small objects with a side length > 10 cm with an absolute accuracy of ± 1 cm", precision about 1 cm for repeated scans, and the scanning mode meshes "the close surroundings (< 5 m)". Good enough for scaling a 2 to 3 m camera to rider distance (about 0.5 percent).
  https://doi.org/10.1038/s41598-021-01763-9 (PubMed abstract: https://pubmed.ncbi.nlm.nih.gov/34782692/)
- AVCameraCalibrationData (iOS 11): intrinsicMatrix is a pinhole model K where "fx and fy are the pixel focal length ... ox and oy values are the offsets of the principal point, from the top-left corner", relative to intrinsicMatrixReferenceDimensions. lensDistortionLookupTable: "Lens distortion is modeled using a one-dimensional lookup table of 32-bit float values evenly distributed along a radius from the center of the distortion to a corner, with each value representing a magnification of the radius. This model assumes symmetrical lens distortion." lensDistortionCenter can differ from the principal point. Calibration data is attached to AVDepthData from the capture device.
  https://developer.apple.com/documentation/avfoundation/avcameracalibrationdata
  https://developer.apple.com/documentation/avfoundation/avcameracalibrationdata/intrinsicmatrix
  https://developer.apple.com/documentation/avfoundation/avcameracalibrationdata/lensdistortionlookuptable
  https://developer.apple.com/documentation/avfoundation/avcameracalibrationdata/lensdistortioncenter
  https://developer.apple.com/documentation/avfoundation/avdepthdata/cameracalibrationdata
- Per frame intrinsics without depth: AVCaptureConnection.isCameraIntrinsicMatrixDeliverySupported / Enabled (iOS 11, set before startRunning). When enabled "any AVCaptureVideoDataOutput instance in this connection can include the kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix attachment for each sample buffer it vends."
  https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliveryenabled
  https://developer.apple.com/documentation/coremedia/kcmsamplebufferattachmentkey_cameraintrinsicmatrix
- Geometric distortion correction: isGeometricDistortionCorrectionEnabled "When the device supports geometric distortion correction (GDC), the default value is true." Format exposes videoFieldOfView and geometricDistortionCorrectedVideoFieldOfView. So on modern iPhones, video frames are already rectilinear by default; the main (24 mm equivalent) camera at 2 to 3 m is close to a pinhole and the ultra wide (13 mm, 120 degree FOV) should be avoided for measurement.
  https://developer.apple.com/documentation/avfoundation/avcapturedevice/isgeometricdistortioncorrectionenabled
  https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/geometricdistortioncorrectedvideofieldofview
- Focal lengths (Apple tech specs): iPhone 15 Pro "48MP Main: 24 mm, f/1.78 aperture", LiDAR Scanner, A17 Pro. iPhone 18 Pro: "48MP Fusion Main with variable aperture ... 24 mm", "48MP Fusion Ultra Wide: 13 mm, f/2.2 aperture and 120° field of view", LiDAR Scanner, A20 Pro.
  https://support.apple.com/en-us/111829
  https://www.apple.com/iphone-18-pro/specs/
- Known object scale: wheel diameter and crank length as a scale bar in the sagittal plane follows the standard 2D recommendation (Stenum 2021 recommends scaling "using a known-length object at the same depth as the walking path", see section 6). A 700c wheel with tire is roughly 0.67 to 0.70 m depending on tire width, so the tire size must be asked or detected; I did not find a primary source stating a fixed value and record this as an app design choice rather than a cited fact.
- CoreMotion leveling: CMDeviceMotion provides attitude ("the orientation of a body relative to a given frame of reference") and gravity separated from userAcceleration because "Core Motion is able to track a device's attitude using both the gyroscope and the accelerometer". This gives phone pitch and roll to level the camera; yaw relative to the bike plane is not observable from the IMU and must come from the image (cameraOriginMatrix of the 3D request, or apparent wheel ellipse / segment length ratios).
  https://developer.apple.com/documentation/coremotion/cmdevicemotion
  https://developer.apple.com/documentation/coremotion/cmdevicemotion/attitude
  https://developer.apple.com/documentation/coremotion/cmdevicemotion/gravity

## 5. Capture: frame rate, stabilization

- Frame rate control: AVCaptureDevice.activeVideoMinFrameDuration "is the reciprocal of its maximum frame rate"; setting a value not in the active format's videoSupportedFrameRateRanges raises an exception; needs lockForConfiguration.
  https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideominframeduration
  https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videosupportedframerateranges
- Device capability: iPhone 15 Pro "1080p HD video recording at 25 fps, 30 fps, or 60 fps", "4K video recording at 24 fps, 25 fps, 30 fps, or 60 fps", "Slo-mo video support for 1080p at 120 fps or 240 fps". iPhone 18 Pro: 4K up to 120 fps on the main camera, 1080p up to 240 fps slo-mo.
  https://support.apple.com/en-us/111829
  https://www.apple.com/iphone-18-pro/specs/
- Sampling argument: at 90 rpm a crank turn takes 0.667 s; 60 fps gives 40 frames per revolution (9 degrees of crank per frame), 30 fps gives 20 (18 degrees per frame). Knee angle changes slowly near BDC, so 60 fps with per frame pose plus a fit of the angle versus crank angle curve is adequate; 120 or 240 fps only matters for fast transients. (Derived, not a citation.)
- Stabilization: preferredVideoStabilizationMode "defaults to off"; "Video stabilization introduces additional latency into the video capture pipeline and may consume more system memory". .standard: "Standard video stabilization has a reduced field of view." .cinematicExtended: "longer latency ... but yields improved stability." .cinematicExtendedEnhanced (iOS 18): "reduced field of view compared to extended cinematic". For measurement, keep stabilization off (default) since electronic stabilization warps the frame and changes the effective intrinsics; use a tripod or lean the phone instead.
  https://developer.apple.com/documentation/avfoundation/avcaptureconnection/preferredvideostabilizationmode
  https://developer.apple.com/documentation/avfoundation/avcapturevideostabilizationmode/standard
  https://developer.apple.com/documentation/avfoundation/avcapturevideostabilizationmode/cinematicextended
  https://developer.apple.com/documentation/avfoundation/avcapturevideostabilizationmode/cinematicextendedenhanced

## 6. Published accuracy of markerless 2D pose for sagittal knee and hip angles

### Cycling specific
- Bini, Serrancoli, Santiago, Pinto, Moura 2023, J Sports Sci 41(1):36-44, "Criterion validity of neural networks to assess lower limb motion during cycling". 26 cyclists on a trainer, one sagittal video camera, reflective marker tracking as criterion, OpenPose and MSRA tested. "Poor to moderate agreement was found for both methods, with OpenPose differing from the criterion by 4-8° for the hip and knee joints. Larger errors were observed for the ankle joint (15-22°)". No significant SPM differences through the crank cycle. This is the most directly relevant study: single sagittal camera, bicycle in view.
  https://pubmed.ncbi.nlm.nih.gov/36975046/ (DOI 10.1080/02640414.2023.2194725)
- Kakavand, Ahmadi, Parsaei, Edwards, Komeili 2025, Comput Biol Med 192:110295, OpenCap (multi phone 3D) vs marker based in cycling, 10 participants: r > 0.9 for hip, knee, ankle flexion; knee flexion RMSE 9.3° (±3.8) left and 10.2° (±4.3) right; hip flexion RMSE 7.9° (±2.6); ankle 10.7° and 12.4°.
  https://pubmed.ncbi.nlm.nih.gov/40311466/
- Serrancoli et al 2020, IEEE Access 8:122782 to 122790, "Marker-Less Monitoring Protocol to Analyze Biomechanical Joint Metrics During Pedaling": OpenPose with two webcams plus force sensors, and a custom algorithm to re-estimate hip, knee, ankle, metatarsal and heel points because pose systems "have difficulties tracking points when part of the body is hidden or when an artifact such as a bicycle is present" (quote from the search snippet of the paper; the IEEE and DOAJ pages returned 403 so the abstract was not read in full).
  https://ieeexplore.ieee.org/document/9131774 (DOI 10.1109/ACCESS.2020.3006423)
- Fonda, Sarabon, Li 2014, J Sports Sci 32(10):940-946: 11 cyclists, 13 camera 3D vs high speed 2D video vs electrogoniometer vs static goniometer for knee angle at BDC. "Compared to 3D kinematics, all other methods statistically significantly underestimated the knee angle"; dynamic methods differ from static (effect sizes 0.4 to 0.6); "2D kinematics is a valid tool for knee angle assessment during bike fitting. However, for higher precision, one should use correction factor by adding 2.2° to the measured value." All dynamic methods had good intra session reliability.
  https://pubmed.ncbi.nlm.nih.gov/24499342/
- Corbett and Bevins 2014, Journal of Science and Cycling 3(2), "Differences in static and dynamic bike fit with 3D motion capture": 15 subjects, Vicon, three sessions. Typical intra session error for knee flexion 1.7° (dynamic) to 4.2° (static); knee flexion 5.4° greater dynamic than static; ankle plantarflexion 7.8° greater, hip flexion 5.1° greater; recommends shifting the 25 to 35° static target to 30 to 40° for dynamic measurement.
  https://lida.sport-iat.de/ta/Record/4032945
- Ferrer-Roca et al 2012, J Strength Cond Res 26(11):3025-3029: static inseam method (106 to 109 percent) left 56.5 percent of well trained cyclists outside the range; 26 percent had knee flexion outside 30 to 40° by the 2D dynamic method; proposes 108.6 to 110.4 percent of inseam.
  https://pubmed.ncbi.nlm.nih.gov/22190163/
- Bini and Priego-Quesada 2022 systematic review, J Sports Sci 40(4):386-400: "Strong evidence suggests that saddle height should be configured using dynamic measurements of the knee angle"; changes under 4 percent of leg length give trivial to small changes in loads.
  https://pubmed.ncbi.nlm.nih.gov/34706617/
- Commercial references: Scoz et al 2021, Sensors 21(13):4473, Retul vs Vicon, 11 amateur triathletes, 18 measures: "six variables indicate a SEM of less than one degree between systems. Only two variables indicate a SEM higher than two degrees". Branco et al 2022, J Sci Cycling, Retul Vantage reliability: sampling rate 18 Hz, 10 cyclists, "Standard error was lower than 3° for all angular variables", minimal detectable difference 2.15 to 6.55°. Bouillod et al 2016 (icSPORTS): Shimano 3D motion analyzer vs Vicon, 3 cyclists, sensor "positioned 2 m away from the sagittal plane", ICC knee flexion 0.97 and knee extension 0.98 for the analyzer. These set the bar an app must approach: about 1 to 3° SEM.
  https://pubmed.ncbi.nlm.nih.gov/34208808/
  https://repositorio.ufmg.br/bitstream/1843/65097/2/Does%20the%20Ret%c3%bcl%20System%20provide%20reliable%20kinematics%20information%20for%20cycling%20analysis_.pdf
  https://www.scitepress.org/Papers/2016/60882/60882.pdf

### Gait and running (single camera 2D, vs marker based 3D)
- Stenum, Rossi, Roemmich 2021, PLoS Comput Biol 17(4):e1008935, OpenPose BODY_25 vs Vicon, 31 adults, cameras 3.3 m from subject at 1.3 m height, 25 Hz 960x540: MAE hip 4.0°, knee 5.6°, ankle 7.4°. "Knee angle errors were largely invariant to position" along the walkway while hip and ankle errors grew at the ends (perspective). Recommendations: higher frame rates and faster shutter, wider FOV with distortion correction, scale with a known length object at the subject's depth, camera perpendicular to the motion plane, mind lighting, clothing and footwear.
  https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1008935
- Wade et al 2023, PLoS One 18(11):e0293917, OpenPose vs 15 camera Qualisys, 15 adults walking, 1920x1080: sagittal knee bias 1.5° with SD 4.1° on the camera side and 1.6° with SD 6.9° on the far (occluded) side; hip -3.6° SD 4.6° camera side vs -4.6° SD 9.5° far side; ankle -8.4° SD 5.2°. SD of bias was 69 percent higher at the knee and 108 percent higher at the hip on the occluded side; authors recommend discounting occluded side angles. For a bike fit this means measure only the camera side leg and film both sides if both are wanted.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10635560/
- Ota et al 2021, Gait Posture 85:290-297, OpenPose vs Vicon, 24 participants treadmill walking and running: sagittal hip, knee, ankle ROM "had large coefficients of determination, without proportional biases"; frontal plane pelvis and hip poor. (A later paper cites this study's knee error as 5.1 ± 2.5°.)
  https://pubmed.ncbi.nlm.nih.gov/33636458/
- Lambricht et al 2025, Sensors 25(3):934, OpenPifPaf on iPhone 12 video (60 Hz, 1280x720, tripod 1 m high, 3 m lateral, perpendicular) vs Vicon, 30 runners at 2.5 and 3.6 m/s: RMSE hip 5.6°, ankle 3.5°, knee 2.9°. Clothing (markers and minimal clothing vs usual running clothes, "typically shorts or leggings ... and loose-fitting t-shirts") changed RMSE by under 2.8° for all joints.
  https://pubmed.ncbi.nlm.nih.gov/39943571/ (full text PMC11819925)
- Srinivasan et al 2025, Biomedical Human Kinetics 17(1):13-25, BlazePose in outdoor running, 16 male athletes, reference was manual Kinovea digitising (2D, not mocap): average MAE 2.11°, RMSE 2.63°, r 0.70 to 0.97; knee slightly worse than hip and ankle.
  https://reference-global.com/article/10.2478/bhk-2025-0002

### Perspective and camera angle
- Baldinger, Reimer, Senner 2025, Sensors 25(3):799, OpenPose from four iPhone cameras at 45 degree intervals (front right, front left, back left, back right) during front lunges, 20 participants, Vicon 200 Hz, video 1194x834 at about 43 fps: knee RMSE 18.2, 29.4, 16.7, 15.5° and hip RMSE 19.0, 25.3, 15.7, 15.2° for the four views; mean absolute deviation at peak knee flexion 8.9 to 33.3° depending on view. "Deeper investigation of the OpenPose video data reveals no estimation errors but rather the issue of perspective when calculating 2D joint angles". The paper cites prior literature RMSE of about 5.1° knee and 5.6° hip for walking, running and cycling in proper sagittal views. Lesson: a 45 degree off axis phone destroys sagittal angle accuracy; the app must enforce a perpendicular view.
  https://www.mdpi.com/1424-8220/25/3/799 (full text PMC11819822)
- Stevens, Schmitt, Cole, Chan 2006, Am J Phys Anthropol, "Technical Note: Out-of-Plane Angular Correction Based on a Trigonometric Function for Use in Two-Dimensional Kinematic Studies": "Elbow and knee-joint angles that are less than 20° out-of-plane of lateral-view cameras generally exhibit very little measurable difference from their 3D counterparts"; beyond that, angles "can appear significantly more extended than they actually are"; the correction recovers each segment's out of plane angle as arccos(apparent length / actual length), needs measured segment lengths, reduces error to under 5 percent, and is not recommended when the proximal or distal reference point also has large out of plane displacement. For the app: compare apparent thigh and shank lengths at the same crank phase against the rider's measured (or LiDAR measured) segment lengths to estimate and flag off axis error.
  https://people.ohio.edu/stevensn/documents/Stevens%20et%20al%202006%20Technical%20note.pdf (DOI 10.1002/ajpa.20359)
- Umberger and Martin 2001, J Appl Biomech 17(1):55-62, "Testing the Planar Assumption during Ergometer Cycling" (DOI 10.1123/jab.17.1.55). Bouillod 2016 summarises it as reporting "no significant difference exist between 3D and 2D kinematic systems" in cycling, whereas Fonda 2014 found a 2.2° underestimate. I could not read the abstract (publisher 403), so only the secondary characterisation is recorded.
  https://doi.org/10.1123/jab.17.1.55

### Clothing and repeatability
- Augustine et al 2025, PeerJ 13:e18613, Theia3D (8 cameras) walking in tight vs loose clothing, 22 adults: "average inter-trial variation of <2°, inter-session variation of <3° and inter-session-clothing variation <3.5°. Root mean square differences (RMSD) between clothing conditions were <2°."
  https://pubmed.ncbi.nlm.nih.gov/39763706/
- Horsak, Kainz, Dumphart 2024, J Biomech 175:112281, OpenCap (smartphone based) test retest, 20 volunteers: RMSD 2.8° walking, 3.3° sit to stand; SEM 2.2° and MDC 6.0° for walking; "Clothing had minimal effects on kinematics by adding on average less than one degree to the RMSD values for most variables"; segment lengths agreed poorly to moderately between clothing conditions; recommends consistent clothing.
  https://pubmed.ncbi.nlm.nih.gov/39163799/
- Takeaway for cyclists: bib shorts and a fitted jersey are the easy case; the literature's "loose" conditions still gave under 3° differences, but segment length estimates (needed for scale and the Stevens correction) were the thing clothing hurt most.

### Lighting
- No controlled study found before the search budget ran out. Stenum 2021 lists lighting as a factor to control, and Apple's WWDC20 notes do not discuss lighting for body pose. Open question.

## 7. Core ML model options

- BlazePose (Bazarevsky et al 2020, arXiv 2006.10204): 33 keypoints, single person, "over 30 frames per second on a Pixel 2", detector plus tracker, heatmap plus regression. MediaPipe Pose Landmarker docs: 33 landmarks, Lite, Full, Heavy variants (detector input 224x224, landmarker 256x256, float16), image, video and live stream modes; the solution page lists Android, Python and Web guides (iOS not listed on that page, though the task framework has historically shipped iOS builds; verify current iOS support before planning on it). BlazePose includes heel and foot index landmarks, which Vision 2D lacks, useful for ankle angle and foot angle.
  https://arxiv.org/abs/2006.10204
  https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker
- MoveNet (TensorFlow blog 2021): 17 COCO keypoints, Lightning (192x192) and Thunder (256x256), "faster than real time (30+ FPS)" on modern phones; benchmark table shows iPhone 12 WebGL 51 fps Lightning and 43 fps Thunder; single person; trained on COCO plus an internal fitness/yoga/dance set.
  https://blog.tensorflow.org/2021/05/next-generation-pose-detection-with-movenet-and-tensorflowjs.html
- RTMPose (arXiv 2303.07399): RTMPose-m 75.8 AP on COCO at 90+ FPS on an Intel i7-11700 CPU and 430+ FPS on a GTX 1660 Ti; RTMPose-s 72.2 AP at 70+ FPS on a Snapdragon 865; RTMPose-l 67.0 AP on COCO-WholeBody (133 keypoints incl feet) at 130+ FPS. No iPhone numbers in the abstract.
  https://arxiv.org/abs/2303.07399
- ViTPose (arXiv 2204.12484): plain ViT backbone, 100M to 1B parameters, 81.1 AP on COCO test-dev for the largest model. Too heavy for real time on phone; a candidate for offline per frame processing of a short clip if converted to Core ML, but no on device latency figures were found.
  https://arxiv.org/abs/2204.12484
- Accuracy framing: COCO AP measures keypoint localisation on in the wild photos; none of these model papers report joint angle error in degrees. The angle error numbers above (Bini 2023, Stenum 2021, Wade 2023, Lambricht 2025) are all for OpenPose or OpenPifPaf; MediaPipe/BlazePose angle validations in the literature mostly used 2D references like Kinovea. No peer reviewed validation of Apple Vision body pose against marker based mocap was found in this pass (open question).

## 8. On device processing time

- Apple gives no published ms figures for VNDetectHumanBodyPoseRequest or the 3D request; WWDC20 only says newer devices can keep up with the camera stream and recommends not holding camera buffers. WWDC19 says ARKit body tracking runs on the Neural Engine. Treat as "bench test on target devices" rather than citable. Third party numbers for MoveNet on iPhone 12 (43 to 51 fps in a browser) and BlazePose at 30+ fps on a Pixel 2 suggest a 60 fps, 30 to 60 s clip can be processed offline on device in under real time on A15 and later chips, but this is an inference, not a measurement.

## 9. Feasibility synthesis (for the spec author)

1. Primary measurement path: record the camera side of the rider at 1080p60 with stabilization off on the main 24 mm camera, phone on a tripod or propped, levelled with CoreMotion pitch and roll, 2 to 3 m away, perpendicular to the bike. Run Vision 2D body pose per frame offline (works on video files, gives per joint confidence, iOS 14+, multi person tolerant). Compute camera side knee and hip angles per frame, fit against crank phase (from ankle or pedal track), report knee angle at BDC, hip angle at TDC, ranges. Expect about 4 to 8° absolute error versus marker based (Bini 2023) and 1 to 3° repeatability, which is comparable to the static goniometer practice many fitters use but not to Retul or 3D systems (about 1 to 3° SEM).
2. Add the 3D request on iOS 17+ for two things only: cameraOriginMatrix to estimate camera yaw relative to the rider (perspective warning), and, on LiDAR devices, measured body height and metric joint positions for scale. Do not rely on 3D joints for angles until benched.
3. Scale: LiDAR depth when available (about 1 cm); otherwise a known length in the sagittal plane (wheel or crank length typed by the user). Perspective check: compare apparent thigh/shank length ratio at matched crank phases to the Stevens 2006 cosine model and refuse to report when the implied off plane angle exceeds about 20°.
4. Known failure modes to design around: far leg occluded by the frame (measure camera side only, ask for a second clip from the other side), aero or drops posture is a "bent over" case Apple names as degraded, flowing clothing, rider near the frame edge, ultra wide lens distortion, electronic stabilization warping, off axis camera. Clothing in bibs is a non issue per the literature.
5. Honest claim for the App Store: "video based dynamic fit guidance" with stated typical error, not "lab accurate". A Vision vs marker based validation of this exact pipeline on a trainer is the obvious piece of evidence that does not exist yet.
