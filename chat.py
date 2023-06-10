import requests
import openai

# Capture du texte de l'éditeur
user_input = "Bonjour, j'ai une question sur mon code Python."

openai.api_key="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"

messages=[
    {
        "role":"system",
        "content":"you are a senior python ad kivy developer"
    }
]

response = openai.Completion.create(
    engine='text-davinci-002',  # Moteur GPT à utiliser (text-davinci-003 est recommandé pour la version la plus récente de ChatGPT)
    prompt='Bonjour, j\'ai une question sur mon code Python.',  # Texte d'entrée utilisateur
    max_tokens=70  ,# Nombre maximum de tokens dans la réponse générée
    temperature=.6,
    messages=messages
)

bot_response = response.choices[0].text.strip()
print("Réponse du modèle : ", bot_response)

# Envoyer la requête à l'API ChatGPT
# api_url = "https://api.openai.com/v1/chat/completions"
# headers = {
#     "Authorization": "Bearer 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",
#     "Content-Type": "application/json"
# }
# data = {
#     "messages": [
#         {
#             "role": "system",
#             "content": "user"
#         },
#         {
#             "role": "user",
#             "content": user_input
#         }
#     ]
# }
# response = requests.post(api_url, headers=headers, json=data)
# response_data = response.json()

# # Récupérer et afficher la réponse
# bot_response = response_data#["choices"][0]["message"]["content"]
# print("Réponse du modèle : ", bot_response)