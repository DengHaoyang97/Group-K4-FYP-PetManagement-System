from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import numpy as np
import io
from tflite_runtime.interpreter import Interpreter

app = FastAPI()

# 允许跨域访问（让 Flutter 或网页可以访问这个接口）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 加载 TFLite 模型
interpreter = Interpreter(model_path="model.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# 示例标签（请改成你自己的 labels.txt 内容）
labels = ["Pedigree", "Royal"]

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        image = image.resize((224, 224))  # 修改为你模型需要的输入大小

        # 图像预处理：归一化并转为模型输入形状
        input_data = np.array(image, dtype=np.float32) / 255.0
        input_data = np.expand_dims(input_data, axis=0)

        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        output_data = interpreter.get_tensor(output_details[0]['index'])[0]

        # 输出结果
        predicted_index = int(np.argmax(output_data))
        confidence = float(output_data[predicted_index])
        return {
            "label": labels[predicted_index],
            "confidence": f"{confidence * 100:.2f}%"
        }
    except Exception as e:
        return {"error": str(e)}
